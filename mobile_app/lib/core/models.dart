// Data classes mirroring the JSON sent by the backend on /ws/detect.

class Detection {
  final List<double> box; // [x1, y1, x2, y2] in the pixel space of the frame we sent
  final double confidence;
  final String className;
  final int? trackId;
  final bool isApproaching;

  const Detection({
    required this.box,
    required this.confidence,
    required this.className,
    this.trackId,
    this.isApproaching = false,
  });

  factory Detection.fromJson(Map<String, dynamic> j) => Detection(
        box: ((j['box'] as List?) ?? const [0, 0, 0, 0])
            .map((e) => (e as num).toDouble())
            .toList(),
        confidence: (j['confidence'] as num?)?.toDouble() ?? 0,
        className: (j['class_name'] as String?) ?? 'object',
        trackId: (j['track_id'] as num?)?.toInt(),
        isApproaching: (j['is_approaching'] as bool?) ?? false,
      );

  bool get isText => className.startsWith('"');
  bool get isFace => className.startsWith('Face:');
}

class Hazard {
  final String className;
  final String directionKey; // left | center | right
  final String proximity;
  final bool isUrgent;
  final int? trackId;

  const Hazard({
    required this.className,
    required this.directionKey,
    required this.proximity,
    required this.isUrgent,
    this.trackId,
  });

  factory Hazard.fromJson(Map<String, dynamic> j) => Hazard(
        className: (j['class_name'] as String?) ?? 'object',
        directionKey: (j['direction_key'] as String?) ?? 'center',
        proximity: (j['proximity'] as String?) ?? '',
        isUrgent: (j['is_urgent'] as bool?) ?? false,
        trackId: (j['track_id'] as num?)?.toInt(),
      );
}

class FrameResult {
  final int frameId;
  final List<Detection> detections;
  final List<Hazard> hazards;
  final String hazardAlert;
  final bool isUrgent;
  final double? corridorXMin; // pixel x-bounds of the walking corridor in the frame we sent
  final double? corridorXMax;
  final double inferenceMs;

  const FrameResult({
    required this.frameId,
    required this.detections,
    required this.hazards,
    required this.hazardAlert,
    required this.isUrgent,
    this.corridorXMin,
    this.corridorXMax,
    required this.inferenceMs,
  });

  factory FrameResult.fromJson(Map<String, dynamic> j) {
    final corridor = (j['corridor'] as Map?)?.cast<String, dynamic>() ?? const {};
    return FrameResult(
      frameId: (j['frame_id'] as num?)?.toInt() ?? 0,
      detections: ((j['detections'] as List?) ?? const [])
          .map((e) => Detection.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      hazards: ((j['hazards'] as List?) ?? const [])
          .map((e) => Hazard.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      hazardAlert: (j['hazard_alert'] as String?) ?? '',
      isUrgent: (j['is_urgent'] as bool?) ?? false,
      corridorXMin: (corridor['x_min'] as num?)?.toDouble(),
      corridorXMax: (corridor['x_max'] as num?)?.toDouble(),
      inferenceMs: (j['inference_time_ms'] as num?)?.toDouble() ?? 0,
    );
  }
}
