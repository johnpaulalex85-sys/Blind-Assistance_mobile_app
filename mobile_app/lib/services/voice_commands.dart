import 'dart:async';

import 'package:speech_to_text/speech_to_text.dart' as stt;

typedef CommandHandler = Future<void> Function(String text);

/// Continuous voice listening: listens, hands each final phrase to [onCommand],
/// pauses while the app is speaking and restarts itself.
class VoiceCommands {
  final stt.SpeechToText _stt = stt.SpeechToText();
  bool _available = false;
  bool active = false;
  late CommandHandler _onCommand;
  late bool Function() _isSpeaking;

  Future<bool> init() async {
    _available = await _stt.initialize(
      onStatus: (s) {
        if (active && (s == 'done' || s == 'notListening')) {
          Timer(const Duration(milliseconds: 300), _listen);
        }
      },
      onError: (_) {
        if (active) Timer(const Duration(seconds: 1), _listen);
      },
    );
    return _available;
  }

  Future<bool> start(CommandHandler onCommand, bool Function() isSpeaking) async {
    if (!_available && !await init()) return false;
    _onCommand = onCommand;
    _isSpeaking = isSpeaking;
    active = true;
    _listen();
    return true;
  }

  Future<void> stop() async {
    active = false;
    await _stt.stop();
  }

  void _listen() {
    if (!active || !_available || _stt.isListening) return;
    if (_isSpeaking()) {
      Timer(const Duration(milliseconds: 500), _listen);
      return;
    }
    _stt.listen(
      onResult: (r) {
        final words = r.recognizedWords.trim().toLowerCase();
        if (r.finalResult && words.isNotEmpty) _onCommand(words);
      },
      listenOptions: stt.SpeechListenOptions(
        partialResults: false,
        cancelOnError: false,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 4),
      ),
    );
  }
}
