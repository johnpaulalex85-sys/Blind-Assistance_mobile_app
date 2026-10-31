import 'package:vibration/vibration.dart';

/// Direction-coded vibration so hazards can be felt as well as heard:
///  centre = 1 pulse, left = 2 short, right = 3 short, urgent = 3 long.
class HapticsService {
  bool enabled = true;
  bool _has = false;

  Future<void> init() async => _has = await Vibration.hasVibrator();

  void alert({required bool urgent, String direction = 'center'}) {
    if (!enabled || !_has) return;
    final List<int> pattern;
    if (urgent) {
      pattern = [0, 400, 100, 400, 100, 400];
    } else if (direction == 'left') {
      pattern = [0, 70, 80, 70];
    } else if (direction == 'right') {
      pattern = [0, 70, 80, 70, 80, 70];
    } else {
      pattern = [0, 150];
    }
    Vibration.vibrate(pattern: pattern);
  }
}
