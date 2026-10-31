import 'dart:async';
import 'dart:ui' show Size;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../core/api_client.dart';
import '../core/detect_socket.dart';
import '../core/models.dart';
import '../services/camera_service.dart';
import '../services/haptics_service.dart';
import '../services/speech_service.dart';
import '../services/voice_commands.dart';

/// Orchestrates camera -> WebSocket -> speech/haptics, plus REST features.
class AppState extends ChangeNotifier {
  // ---- settings (persisted) -------------------------------------------------
  String serverUrl = '';
  String apiKey = '';
  double speechRate = 0.5;
  int analysisIntervalSec = 8;
  bool hapticsEnabled = true;
  bool skipDuplicates = true;

  // ---- runtime ----------------------------------------------------------------
  final String sid = const Uuid().v4();
  final camera = CameraService();
  final speech = SpeechService();
  final haptics = HapticsService();
  final voice = VoiceCommands();

  ApiClient? api;
  DetectSocket? _socket;
  StreamSubscription? _resSub, _stateSub;

  LinkState link = LinkState.disconnected;
  FrameResult? last;
  Size frameSize = const Size(480, 640);
  bool running = false;
  bool loaded = false;
  bool voiceOn = false;
  bool continuous = false;
  String? error;
  final List<String> log = [];

  /// Set by the UI so a voice command can open the face-registration screen.
  VoidCallback? onOpenFaceRegister;

  bool _inFlight = false;
  Timer? _watchdog, _safetyTimer, _analysisTimer;
  DateTime _lastResultAt = DateTime.now();
  DateTime _lastLostWarning = DateTime.fromMillisecondsSinceEpoch(0);
  bool _analyzing = false;
  bool _spokeAuthHint = false;

  bool get configured => serverUrl.trim().isNotEmpty;

  // ---- lifecycle ----------------------------------------------------------------
  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    serverUrl = p.getString('serverUrl') ?? '';
    apiKey = p.getString('apiKey') ?? '';
    speechRate = p.getDouble('speechRate') ?? 0.5;
    analysisIntervalSec = p.getInt('interval') ?? 8;
    hapticsEnabled = p.getBool('haptics') ?? true;
    skipDuplicates = p.getBool('skipDup') ?? true;
    speech.rate = speechRate;
    speech.skipDuplicates = skipDuplicates;
    haptics.enabled = hapticsEnabled;
    await speech.init();
    await haptics.init();
    loaded = true;
    notifyListeners();
  }

  Future<void> saveSettings({
    required String url,
    required String key,
    required double rate,
    required int interval,
    required bool haptic,
    required bool skipDup,
  }) async {
    final changedServer = url.trim() != serverUrl || key.trim() != apiKey;
    serverUrl = _normalizeUrl(url);
    apiKey = key.trim();
    speechRate = rate;
    analysisIntervalSec = interval;
    hapticsEnabled = haptic;
    skipDuplicates = skipDup;
    final p = await SharedPreferences.getInstance();
    await p.setString('serverUrl', serverUrl);
    await p.setString('apiKey', apiKey);
    await p.setDouble('speechRate', rate);
    await p.setInt('interval', interval);
    await p.setBool('haptics', haptic);
    await p.setBool('skipDup', skipDup);
    await speech.setRate(rate);
    speech.skipDuplicates = skipDup;
    haptics.enabled = haptic;
    if (changedServer && running) await _connect();
    notifyListeners();
  }

  String _normalizeUrl(String u) {
    var s = u.trim();
    if (s.isEmpty) return s;
    if (!s.startsWith('http://') && !s.startsWith('https://')) s = 'http://$s';
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }

  /// Opens the camera, connects to the server and starts streaming frames.
  Future<bool> start() async {
    if (running) return true;
    if (!configured) {
      error = 'Server address not set';
      notifyListeners();
      return false;
    }
    try {
      await camera.init();
    } catch (e) {
      error = 'Camera unavailable. Please allow camera access.';
      await speech.say(error!, force: true);
      notifyListeners();
      return false;
    }
    await WakelockPlus.enable();
    await _connect();
    await camera.startStream(() => !_inFlight && link == LinkState.connected, (jpeg, size) {
      frameSize = size;
      _inFlight = true;
      _socket?.sendFrame(jpeg);
      _watchdog?.cancel();
      _watchdog = Timer(const Duration(seconds: 2), () => _inFlight = false);
    });
    _lastResultAt = DateTime.now();
    _safetyTimer = Timer.periodic(const Duration(seconds: 1), (_) => _safetyCheck());
    running = true;
    error = null;
    notifyListeners();
    return true;
  }

  Future<void> _connect() async {
    await _resSub?.cancel();
    await _stateSub?.cancel();
    await _socket?.close();
    api = ApiClient(baseUrl: serverUrl, apiKey: apiKey);
    final s = DetectSocket(baseUrl: serverUrl, apiKey: apiKey, sessionId: sid);
    _socket = s;
    _stateSub = s.states.listen((st) {
      link = st;
      if (st == LinkState.disconnected && s.failures == 3 && !_spokeAuthHint) {
        _spokeAuthHint = true;
        speech.say('Cannot reach the server. Check the address and key in settings.', force: true);
      }
      if (st == LinkState.connected) _spokeAuthHint = false;
      notifyListeners();
    });
    _resSub = s.results.listen(_onResult);
    s.connect();
  }

  void _onResult(FrameResult r) {
    _inFlight = false;
    _lastResultAt = DateTime.now();
    last = r;
    if (r.hazardAlert.isNotEmpty) {
      speech.say(r.hazardAlert, urgent: r.isUrgent);
      final dir = r.hazards.isNotEmpty ? r.hazards.first.directionKey : 'center';
      haptics.alert(urgent: r.isUrgent, direction: dir);
    }
    notifyListeners();
  }

  /// Safety fallback: if no result arrives for 3 s while running, warn the user.
  void _safetyCheck() {
    if (!running) return;
    final silent = DateTime.now().difference(_lastResultAt);
    if (silent > const Duration(seconds: 3) &&
        DateTime.now().difference(_lastLostWarning) > const Duration(seconds: 15)) {
      _lastLostWarning = DateTime.now();
      speech.say('Detection lost. Please stop and be careful.', urgent: true);
      haptics.alert(urgent: true);
    }
  }

  Future<void> stop() async {
    running = false;
    continuous = false;
    notifyListeners();
    _analysisTimer?.cancel();
    _safetyTimer?.cancel();
    _watchdog?.cancel();
    await stopVoice();
    await camera.dispose();
    await _resSub?.cancel();
    await _stateSub?.cancel();
    await _socket?.close();
    _socket = null;
    link = LinkState.disconnected;
    await WakelockPlus.disable();
    notifyListeners();
  }

  // ---- scene description / questions ------------------------------------------------
  Future<void> describe({bool quiet = false}) async {
    if (_analyzing || api == null) return;
    _analyzing = true;
    try {
      if (!quiet) await speech.say('Analyzing scene.', force: true);
      final r = await api!.describe(sid);
      final text = (r['description'] ?? r['message'] ?? '').toString();
      if (r['success'] == true && text.isNotEmpty) {
        _log('Scene: $text');
        await speech.say(text, force: true);
      } else if (!quiet) {
        await speech.say('I could not analyze the scene. $text', force: true);
      }
    } catch (e) {
      if (!quiet) await speech.say('Request failed. $e', force: true);
    } finally {
      _analyzing = false;
    }
  }

  Future<void> ask(String question) async {
    if (api == null) return;
    _log('You: $question');
    try {
      final r = await api!.ask(question, sid);
      final text = (r['answer'] ?? r['description'] ?? r['message'] ?? 'I do not know.').toString();
      _log('Assistant: $text');
      await speech.say(text, force: true);
    } catch (e) {
      await speech.say('Sorry, I could not get an answer. $e', force: true);
    }
  }

  // ---- continuous analysis -------------------------------------------------------------
  void setContinuous(bool on) {
    continuous = on;
    _analysisTimer?.cancel();
    if (on) {
      speech.say('Continuous analysis on.', force: true);
      _scheduleAnalysis();
    } else {
      speech.say('Continuous analysis off.', force: true);
    }
    notifyListeners();
  }

  void _scheduleAnalysis() {
    _analysisTimer?.cancel();
    _analysisTimer = Timer(Duration(seconds: analysisIntervalSec), () async {
      if (!continuous) return;
      if (!speech.speaking) await describe(quiet: true);
      if (continuous) _scheduleAnalysis();
    });
  }

  // ---- voice ----------------------------------------------------------------------------
  Future<void> toggleVoice() async => voiceOn ? stopVoice(announce: true) : startVoice();

  Future<void> startVoice() async {
    final ok = await voice.start(handleCommand, () => speech.speaking);
    voiceOn = ok;
    await speech.say(ok ? 'Listening. Say help for commands.' : 'Voice recognition is unavailable.', force: true);
    notifyListeners();
  }

  Future<void> stopVoice({bool announce = false}) async {
    if (!voiceOn) return;
    await voice.stop();
    voiceOn = false;
    if (announce) await speech.say('Voice off.', force: true);
    notifyListeners();
  }

  Future<void> handleCommand(String t) async {
    _log('Heard: $t');
    bool has(List<String> w) => w.any(t.contains);
    if (has(['help', 'what can i say', 'commands'])) {
      await speech.say(
          'You can say: what do you see, read the text, who is here, is the path clear, '
          'start analysis, stop analysis, register face, or stop listening.',
          force: true);
    } else if (has(['stop listening', 'voice off'])) {
      await stopVoice(announce: true);
    } else if (has(['stop', 'pause', 'disable', 'turn off']) && has(['analy', 'scene', 'continuous'])) {
      setContinuous(false);
    } else if (has(['start', 'begin', 'enable', 'turn on']) && has(['analy', 'scene', 'continuous'])) {
      setContinuous(true);
    } else if (has(['register', 'scan face', 'save face', 'remember face', 'new face'])) {
      await speech.say('Opening face registration.', force: true);
      onOpenFaceRegister?.call();
    } else {
      await ask(t);
    }
  }

  // ---- faces ------------------------------------------------------------------------------
  /// Grabs five frames half a second apart from the live camera and registers them.
  Future<String> registerFace(String name, {void Function(int)? onProgress}) async {
    if (api == null) return 'Not connected to the server.';
    final frames = <Uint8List>[];
    for (var i = 0; i < 5; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
      final f = camera.lastJpeg;
      if (f != null) frames.add(Uint8List.fromList(f));
      onProgress?.call(i + 1);
    }
    if (frames.isEmpty) return 'No camera frames captured.';
    try {
      final r = await api!.registerFaceMulti(name, frames);
      return (r['message'] ?? (r['success'] == true ? 'Face registered.' : 'Registration failed.')).toString();
    } catch (e) {
      return 'Registration failed. $e';
    }
  }

  Future<String> testConnection() async {
    try {
      final h = await ApiClient(baseUrl: serverUrl, apiKey: apiKey).health();
      final auth = h['auth_required'] == true;
      if (auth) await ApiClient(baseUrl: serverUrl, apiKey: apiKey).listFaces(); // verifies the key
      return 'Connected to server version ${h['version']}.';
    } catch (e) {
      return 'Connection failed: $e';
    }
  }

  void _log(String s) {
    log.insert(0, s);
    if (log.length > 40) log.removeLast();
  }

  @override
  void dispose() {
    stop();
    camera.dispose();
    super.dispose();
  }
}
