import 'dart:io' show Platform;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

/// Plain data holder so a camera frame can be sent to a background isolate.
class FrameJob {
  FrameJob({
    required this.width,
    required this.height,
    required this.planes,
    required this.rowStrides,
    required this.pixelStrides,
    required this.isBgra,
    required this.rotation,
    required this.step,
    required this.quality,
  });

  final int width, height, rotation, step, quality;
  final List<Uint8List> planes;
  final List<int> rowStrides, pixelStrides;
  final bool isBgra;
}

/// Runs in a background isolate: camera frame -> upright, optionally downscaled JPEG.
Uint8List encodeFrame(FrameJob j) {
  final step = j.step < 1 ? 1 : j.step;
  final ow = j.width ~/ step, oh = j.height ~/ step;
  img.Image out;

  if (j.isBgra) {
    out = img.Image.fromBytes(
      width: j.width,
      height: j.height,
      bytes: j.planes[0].buffer,
      rowStride: j.rowStrides[0],
      order: img.ChannelOrder.bgra,
      numChannels: 4,
    );
    if (step > 1) out = img.copyResize(out, width: ow, height: oh);
  } else {
    final yP = j.planes[0], uP = j.planes[1], vP = j.planes[2];
    final yRow = j.rowStrides[0];
    final uRow = j.rowStrides[1], uPix = j.pixelStrides[1];
    final vRow = j.rowStrides[2], vPix = j.pixelStrides[2];
    out = img.Image(width: ow, height: oh);
    for (var y = 0; y < oh; y++) {
      final sy = y * step;
      for (var x = 0; x < ow; x++) {
        final sx = x * step;
        final yy = yP[sy * yRow + sx];
        final u = uP[(sy >> 1) * uRow + (sx >> 1) * uPix] - 128;
        final v = vP[(sy >> 1) * vRow + (sx >> 1) * vPix] - 128;
        final r = (yy + 1.402 * v).round().clamp(0, 255).toInt();
        final g = (yy - 0.344136 * u - 0.714136 * v).round().clamp(0, 255).toInt();
        final b = (yy + 1.772 * u).round().clamp(0, 255).toInt();
        out.setPixelRgb(x, y, r, g, b);
      }
    }
  }
  if (j.rotation != 0) out = img.copyRotate(out, angle: j.rotation);
  return Uint8List.fromList(img.encodeJpg(out, quality: j.quality));
}

typedef JpegCallback = void Function(Uint8List jpeg, Size size);

class CameraService {
  CameraController? controller;
  Uint8List? lastJpeg; // most recent encoded frame (used for face registration)
  bool _busy = false;
  int step = 1; // 1 = full camera resolution, 2 = half
  int quality = 55;

  bool get ready => controller?.value.isInitialized ?? false;

  Future<void> init() async {
    final cams = await availableCameras();
    final cam = cams.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cams.first,
    );
    final c = CameraController(
      cam,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.yuv420 : ImageFormatGroup.bgra8888,
    );
    await c.initialize();
    await c.lockCaptureOrientation(DeviceOrientation.portraitUp);
    controller = c;
  }

  /// [canSend] is checked before any conversion work so frames are skipped cheaply
  /// while the previous one is still being processed by the server.
  Future<void> startStream(bool Function() canSend, JpegCallback onJpeg) async {
    final c = controller!;
    final rotation = c.description.sensorOrientation;
    await c.startImageStream((CameraImage im) async {
      if (_busy || !canSend()) return;
      _busy = true;
      try {
        final job = FrameJob(
          width: im.width,
          height: im.height,
          planes: im.planes.map((p) => p.bytes).toList(),
          rowStrides: im.planes.map((p) => p.bytesPerRow).toList(),
          pixelStrides: im.planes.map((p) => p.bytesPerPixel ?? 1).toList(),
          isBgra: im.planes.length == 1,
          rotation: rotation,
          step: step,
          quality: quality,
        );
        final jpeg = await compute(encodeFrame, job);
        lastJpeg = jpeg;
        final swap = rotation == 90 || rotation == 270;
        final w = (swap ? im.height : im.width) / step;
        final h = (swap ? im.width : im.height) / step;
        onJpeg(jpeg, Size(w, h));
      } catch (_) {
        // drop the frame
      } finally {
        _busy = false;
      }
    });
  }

  Future<void> stopStream() async {
    final c = controller;
    if (c != null && c.value.isStreamingImages) await c.stopImageStream();
  }

  Future<void> dispose() async {
    await stopStream();
    await controller?.dispose();
    controller = null;
  }
}
