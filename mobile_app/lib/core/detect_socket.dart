import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'models.dart';

enum LinkState { disconnected, connecting, connected }

/// WebSocket client for /ws/detect with auto-reconnect (500 ms growing to 3 s).
class DetectSocket {
  DetectSocket({
    required this.baseUrl,
    required this.apiKey,
    required this.sessionId,
    this.wantDepth = false,
  });

  final String baseUrl;
  final String apiKey;
  final String sessionId;
  final bool wantDepth;

  final _results = StreamController<FrameResult>.broadcast();
  final _states = StreamController<LinkState>.broadcast();

  WebSocketChannel? _ch;
  Timer? _retry;
  bool _wanted = false;
  int _delayMs = 500;

  LinkState state = LinkState.disconnected;
  int failures = 0; // consecutive failed connection attempts

  Stream<FrameResult> get results => _results.stream;
  Stream<LinkState> get states => _states.stream;

  Uri _uri() {
    final u = Uri.parse(baseUrl);
    return u.replace(
      scheme: u.scheme == 'https' ? 'wss' : 'ws',
      path: '/ws/detect',
      queryParameters: {
        'sid': sessionId,
        if (apiKey.isNotEmpty) 'token': apiKey,
        'depth': wantDepth ? '1' : '0',
      },
    );
  }

  void _emit(LinkState s) {
    state = s;
    if (!_states.isClosed) _states.add(s);
  }

  void connect() {
    _wanted = true;
    _open();
  }

  void _open() {
    _retry?.cancel();
    _emit(LinkState.connecting);
    final WebSocketChannel ch;
    try {
      ch = WebSocketChannel.connect(_uri());
    } catch (_) {
      failures++;
      _scheduleRetry();
      return;
    }
    _ch = ch;
    ch.ready.then((_) {
      if (_ch == ch) {
        _delayMs = 500;
        failures = 0;
        _emit(LinkState.connected);
      }
    }).catchError((_) {});
    ch.stream.listen(
      (data) {
        if (data is String) {
          try {
            _results.add(FrameResult.fromJson(jsonDecode(data) as Map<String, dynamic>));
          } catch (_) {/* ignore malformed frame */}
        }
      },
      onDone: () => _lost(ch),
      onError: (_) => _lost(ch),
      cancelOnError: true,
    );
  }

  void _lost(WebSocketChannel ch) {
    if (_ch != ch) return;
    _ch = null;
    failures++;
    _emit(LinkState.disconnected);
    _scheduleRetry();
  }

  void _scheduleRetry() {
    if (!_wanted) return;
    _retry = Timer(Duration(milliseconds: _delayMs), _open);
    _delayMs = min(3000, (_delayMs * 1.5).round());
  }

  void sendFrame(Uint8List jpeg) {
    if (state == LinkState.connected) _ch?.sink.add(jpeg);
  }

  Future<void> close() async {
    _wanted = false;
    _retry?.cancel();
    final ch = _ch;
    _ch = null;
    await ch?.sink.close();
    _emit(LinkState.disconnected);
    await _results.close();
    await _states.close();
  }
}
