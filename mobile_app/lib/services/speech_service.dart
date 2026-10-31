import 'package:flutter_tts/flutter_tts.dart';

/// Text-to-speech with the same rules as the web client:
/// urgent alerts interrupt, normal alerts never cut off speech in progress,
/// and identical alerts are suppressed for a few seconds.
class SpeechService {
  final FlutterTts _tts = FlutterTts();
  bool speaking = false;
  bool skipDuplicates = true;
  double rate = 0.5;
  String _last = '';
  DateTime _lastAt = DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> init() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(rate);
    await _tts.setVolume(1.0);
    _tts.setStartHandler(() => speaking = true);
    _tts.setCompletionHandler(() => speaking = false);
    _tts.setCancelHandler(() => speaking = false);
    _tts.setErrorHandler((_) => speaking = false);
  }

  Future<void> setRate(double r) async {
    rate = r;
    await _tts.setSpeechRate(r);
  }

  /// [force] = descriptions/answers: always interrupt whatever is playing.
  Future<void> say(String text, {bool urgent = false, bool force = false}) async {
    if (text.trim().isEmpty) return;
    final now = DateTime.now();
    if (!force && skipDuplicates && text == _last && now.difference(_lastAt) < const Duration(seconds: 6)) {
      return;
    }
    if (speaking && !urgent && !force) return;
    if (speaking) await _tts.stop();
    _last = text;
    _lastAt = now;
    speaking = true;
    await _tts.speak(text);
  }

  Future<void> stop() async {
    await _tts.stop();
    speaking = false;
  }
}
