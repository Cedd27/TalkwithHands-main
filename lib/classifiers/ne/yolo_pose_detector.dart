import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

const int kYoloPoseInputSize = 576;
const int kYoloPoseKeypointCount = 46;
const int kYoloPoseChannels = 4 + 1 + kYoloPoseKeypointCount * 3;
const int kYoloPoseBoxCount = 6804;

class YoloPoseKeypoint {
  const YoloPoseKeypoint({
    required this.x,
    required this.y,
    required this.visibility,
  });

  final double x;
  final double y;
  final double visibility;
}

class YoloPoseDetection {
  const YoloPoseDetection({
    required this.label,
    required this.cx,
    required this.cy,
    required this.width,
    required this.height,
    required this.confidence,
    required this.keypoints,
  });

  final String label;
  final double cx;
  final double cy;
  final double width;
  final double height;
  final double confidence;
  final List<YoloPoseKeypoint> keypoints;

  double get left => cx - width / 2;
  double get top => cy - height / 2;
  double get right => cx + width / 2;
  double get bottom => cy + height / 2;

  YoloPoseDetection scaleToOriginal(int originalWidth, int originalHeight) {
    return YoloPoseDetection(
      label: label,
      cx: cx * originalWidth,
      cy: cy * originalHeight,
      width: width * originalWidth,
      height: height * originalHeight,
      confidence: confidence,
      keypoints: keypoints
          .map(
            (point) => YoloPoseKeypoint(
              x: point.x * originalWidth,
              y: point.y * originalHeight,
              visibility: point.visibility,
            ),
          )
          .toList(growable: false),
    );
  }
}

class YoloPoseDetector {
  YoloPoseDetector({
    this.modelAssetPath = 'assets/ml/best.tflite',
    this.labelsAssetPath = 'assets/ml/best_labels.txt',
    this.threads = 2,
  });

  final String modelAssetPath;
  final String labelsAssetPath;
  final int threads;

  Interpreter? _interpreter;
  List<String> _labels = const [];

  bool get isReady => _interpreter != null;

  Future<void> load() async {
    if (_interpreter != null) return;
    _labels = await _loadLabels();
    final options = InterpreterOptions()..threads = threads;
    _interpreter = await Interpreter.fromAsset(modelAssetPath, options: options);
    _interpreter!.allocateTensors();

    final inputShape = _interpreter!.getInputTensor(0).shape;
    final outputShape = _interpreter!.getOutputTensor(0).shape;
    debugPrint('YOLO pose model loaded: input=$inputShape output=$outputShape');
  }

  Future<List<String>> _loadLabels() async {
    try {
      final text = await rootBundle.loadString(labelsAssetPath);
      final labels = text
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList(growable: false);
      return labels.isEmpty ? const ['signer'] : labels;
    } catch (error) {
      debugPrint('YOLO pose labels disabled: $error');
      return const ['signer'];
    }
  }

  /// Runs the model from an RGBA image buffer.
  ///
  /// [rgbaBytes] must contain 4 bytes per pixel in left-to-right, top-to-bottom
  /// RGBA order. Coordinates returned by this method are normalized 0..1;
  /// call [YoloPoseDetection.scaleToOriginal] to convert them to pixels.
  Future<List<YoloPoseDetection>> detectRgba(
    Uint8List rgbaBytes, {
    required int width,
    required int height,
    double confThreshold = 0.5,
    double iouThreshold = 0.45,
  }) async {
    final interpreter = _interpreter;
    if (interpreter == null) {
      throw StateError('YoloPoseDetector.load() must be called first.');
    }
    if (rgbaBytes.length < width * height * 4) {
      throw ArgumentError('RGBA buffer is smaller than width * height * 4.');
    }

    final input = _preprocessRgba(rgbaBytes, width, height);
    final output = [
      List.generate(
        kYoloPoseChannels,
        (_) => List<double>.filled(kYoloPoseBoxCount, 0),
        growable: false,
      ),
    ];

    interpreter.run(input, output);
    return _decodeOutput(
      output[0],
      confThreshold: confThreshold,
      iouThreshold: iouThreshold,
    );
  }

  /// Decodes raw model output shaped as [143][6804].
  ///
  /// This is useful if you already ran the interpreter elsewhere and only need
  /// YOLO-pose postprocessing.
  List<YoloPoseDetection> decodeRawOutput(
    List<List<double>> raw, {
    double confThreshold = 0.5,
    double iouThreshold = 0.45,
  }) {
    return _decodeOutput(
      raw,
      confThreshold: confThreshold,
      iouThreshold: iouThreshold,
    );
  }

  Float32List _preprocessRgba(Uint8List rgbaBytes, int width, int height) {
    const inputPixels = kYoloPoseInputSize * kYoloPoseInputSize;
    final input = Float32List(1 * 3 * inputPixels);

    // Plain resize to 576x576, CHW order, normalized 0..1. This matches the
    // Kotlin sample's behavior. If training used letterbox preprocessing, this
    // should be changed to preserve aspect ratio and track padding offsets.
    for (var y = 0; y < kYoloPoseInputSize; y++) {
      final srcY = min(
        height - 1,
        max(0, (y * height / kYoloPoseInputSize).floor()),
      );
      for (var x = 0; x < kYoloPoseInputSize; x++) {
        final srcX = min(
          width - 1,
          max(0, (x * width / kYoloPoseInputSize).floor()),
        );
        final src = (srcY * width + srcX) * 4;
        final dst = y * kYoloPoseInputSize + x;

        input[dst] = rgbaBytes[src] / 255.0;
        input[inputPixels + dst] = rgbaBytes[src + 1] / 255.0;
        input[inputPixels * 2 + dst] = rgbaBytes[src + 2] / 255.0;
      }
    }

    return input;
  }

  List<YoloPoseDetection> _decodeOutput(
    List<List<double>> raw, {
    required double confThreshold,
    required double iouThreshold,
  }) {
    if (raw.length < kYoloPoseChannels) {
      throw ArgumentError(
        'Expected at least $kYoloPoseChannels output channels, got ${raw.length}.',
      );
    }

    final candidates = <YoloPoseDetection>[];
    for (var i = 0; i < kYoloPoseBoxCount; i++) {
      final confidence = raw[4][i];
      if (confidence < confThreshold) continue;

      final keypoints = <YoloPoseKeypoint>[];
      for (var k = 0; k < kYoloPoseKeypointCount; k++) {
        final base = 5 + k * 3;
        keypoints.add(
          YoloPoseKeypoint(
            x: raw[base][i],
            y: raw[base + 1][i],
            visibility: raw[base + 2][i],
          ),
        );
      }

      candidates.add(
        YoloPoseDetection(
          label: _labels.isEmpty ? 'signer' : _labels.first,
          cx: raw[0][i],
          cy: raw[1][i],
          width: raw[2][i],
          height: raw[3][i],
          confidence: confidence,
          keypoints: keypoints,
        ),
      );
    }

    return _nonMaxSuppression(candidates, iouThreshold);
  }

  List<YoloPoseDetection> _nonMaxSuppression(
    List<YoloPoseDetection> detections,
    double iouThreshold,
  ) {
    final sorted = detections.toList(growable: true)
      ..sort((a, b) => b.confidence.compareTo(a.confidence));
    final kept = <YoloPoseDetection>[];

    while (sorted.isNotEmpty) {
      final best = sorted.removeAt(0);
      kept.add(best);
      sorted.removeWhere((candidate) => _iou(best, candidate) > iouThreshold);
    }

    return kept;
  }

  double _iou(YoloPoseDetection a, YoloPoseDetection b) {
    final interLeft = max(a.left, b.left);
    final interTop = max(a.top, b.top);
    final interRight = min(a.right, b.right);
    final interBottom = min(a.bottom, b.bottom);

    final interArea =
        max(0.0, interRight - interLeft) * max(0.0, interBottom - interTop);
    final areaA = a.width * a.height;
    final areaB = b.width * b.height;
    final unionArea = areaA + areaB - interArea;

    return unionArea <= 0 ? 0 : interArea / unionArea;
  }

  void close() {
    _interpreter?.close();
    _interpreter = null;
  }
}
