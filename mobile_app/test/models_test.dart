import 'package:flutter_test/flutter_test.dart';
import 'package:vision_assistant/core/models.dart';

void main() {
  test('FrameResult parses a backend /ws/detect message', () {
    final r = FrameResult.fromJson({
      'frame_id': 7,
      'inference_time_ms': 42.5,
      'detections': [
        {'box': [10, 20, 110, 220], 'confidence': 0.91, 'class_name': 'person', 'track_id': 3, 'is_approaching': true},
        {'box': [0, 0, 5, 5], 'confidence': 0.5, 'class_name': 'wall'},
      ],
      'hazards': [
        {'class_name': 'person', 'direction_key': 'left', 'proximity': 'close', 'is_urgent': true, 'track_id': 3}
      ],
      'hazard_alert': 'Stop, person approaching on your left.',
      'is_urgent': true,
      'corridor': {'x_min': 205.0, 'x_max': 435.0},
      'depth_map': null,
    });
    expect(r.frameId, 7);
    expect(r.detections.length, 2);
    expect(r.detections.first.isApproaching, true);
    expect(r.detections.last.trackId, isNull);
    expect(r.hazards.single.directionKey, 'left');
    expect(r.isUrgent, true);
    expect(r.corridorXMin, 205.0);
  });

  test('FrameResult tolerates missing fields', () {
    final r = FrameResult.fromJson({});
    expect(r.detections, isEmpty);
    expect(r.hazardAlert, '');
    expect(r.corridorXMin, isNull);
  });
}
