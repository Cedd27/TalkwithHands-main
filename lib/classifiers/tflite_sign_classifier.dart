import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import 'sign_classifier.dart';

// ── How many frames the LSTM expects (must match train_sign_sequence_model.py)
// Set to false once the labels look right.
const bool kDebugSequence = true;

const int kSequenceFrames = 30;
const int _kMinimumSequenceFrames = 12;
const int _kLandmarks = 21;
const int _kSequenceFeatures = _kLandmarks * 3;
final RegExp _alphabetLabelPattern = RegExp(r'^[A-Z]$');

class TfliteSignClassifier {
  TfliteSignClassifier({
    this.modelAssetPath = 'assets/ml/sign_landmark_classifier.tflite',
    this.labelsAssetPath = 'assets/ml/labels.txt',
    this.sequenceModelAssetPath = 'assets/ml/sign_sequence_classifier.tflite',
    this.sequenceLabelsAssetPath = 'assets/ml/sequence_labels.txt',
    this.minimumConfidence = 0.78,
    this.sequenceMinimumConfidence = 0.6,
  });

  final String modelAssetPath;
  final String labelsAssetPath;
  final String sequenceModelAssetPath;
  final String sequenceLabelsAssetPath;
  final double minimumConfidence;
  final double sequenceMinimumConfidence;

  // Static (dense) model
  Interpreter? _interpreter;
  IsolateInterpreter? _isolateInterpreter;
  List<String> _labels = const [];
  int _outputCount = 0;

  // Sequence (LSTM) model
  Interpreter? _seqInterpreter;
  IsolateInterpreter? _seqIsolateInterpreter;
  List<String> _seqLabels = const [];
  int _seqOutputCount = 0;

  // Rolling frame buffer fed by the camera pipeline
  final List<List<double>> _frameBuffer = [];

  bool get isReady => _isolateInterpreter != null && _labels.isNotEmpty;
  bool get isSequenceReady =>
      _seqIsolateInterpreter != null && _seqLabels.isNotEmpty;

  // ── Load ──────────────────────────────────────────────────────────────────

  Future<void> load() async {
    await _loadStatic();
    await _loadSequence();
  }

  Future<void> _loadStatic() async {
    try {
      final labelsText = await rootBundle.loadString(labelsAssetPath);
      _labels = labelsText
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList(growable: false);
      final options = InterpreterOptions()..threads = 2;
      _interpreter = await Interpreter.fromAsset(
        modelAssetPath,
        options: options,
      );
      _interpreter!.allocateTensors();
      final outputShape = _interpreter!.getOutputTensor(0).shape;
      _outputCount = outputShape.isNotEmpty ? outputShape.last : _labels.length;
      // PERF FIX: run this interpreter on its own isolate so per-frame
      // inference never blocks the main/UI isolate (that blocking was the
      // actual cause of the tracked-hand "lagging behind" — .run() on a
      // plain Interpreter is a synchronous FFI call on whichever isolate
      // calls it).
      _isolateInterpreter = await IsolateInterpreter.create(
        address: _interpreter!.address,
      );
      debugPrint('TFLite static model loaded (${_labels.length} labels)');
    } catch (e) {
      _labels = const [];
      _outputCount = 0;
      _isolateInterpreter?.close();
      _isolateInterpreter = null;
      _interpreter?.close();
      _interpreter = null;
      debugPrint('TFLite static model disabled: $e');
    }
  }

  Future<void> _loadSequence() async {
    try {
      final labelsText = await rootBundle.loadString(sequenceLabelsAssetPath);
      _seqLabels = labelsText
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList(growable: false);
      final options = InterpreterOptions()..threads = 2;
      _seqInterpreter = await Interpreter.fromAsset(
        sequenceModelAssetPath,
        options: options,
      );
      _seqInterpreter!.allocateTensors();
      final outputShape = _seqInterpreter!.getOutputTensor(0).shape;
      _seqOutputCount =
          outputShape.isNotEmpty ? outputShape.last : _seqLabels.length;
      // Same fix as the static model — this one matters even more since the
      // LSTM run is heavier and was causing a bigger stutter every ~30 frames.
      _seqIsolateInterpreter = await IsolateInterpreter.create(
        address: _seqInterpreter!.address,
      );
      debugPrint('TFLite sequence model loaded (${_seqLabels.length} labels)');
    } catch (e) {
      _seqLabels = const [];
      _seqOutputCount = 0;
      _seqIsolateInterpreter?.close();
      _seqIsolateInterpreter = null;
      _seqInterpreter?.close();
      _seqInterpreter = null;
      debugPrint('TFLite sequence model disabled (not trained yet): $e');
    }
  }

  // ── Static classification ─────────────────────────────────────────────────

  Future<SignResult?> classifyAlphabet(List<HandLandmark> landmarks) =>
      _classify(landmarks, _alphabetLabelPattern.hasMatch, 'alphabet');

  Future<SignResult?> classifyNumber(List<HandLandmark> landmarks) =>
      _classify(landmarks, (l) => int.tryParse(l) != null, 'number');

  Future<SignResult?> classifyWordsFromHands(
    List<List<HandLandmark>>? hands,
  ) async {
    if (hands == null || hands.isEmpty) return null;
    return _classify(
      hands.first,
      (l) => !_alphabetLabelPattern.hasMatch(l) && int.tryParse(l) == null,
      'word',
    );
  }

  Future<SignResult?> _classify(
    List<HandLandmark> landmarks,
    bool Function(String) acceptsLabel,
    String type,
  ) async {
    final isolateInterpreter = _isolateInterpreter;
    if (isolateInterpreter == null ||
        _labels.isEmpty ||
        landmarks.length < 21) {
      return null;
    }

    final input = [_normalizeLandmarks(landmarks)];
    final outputCount = _outputCount == 0 ? _labels.length : _outputCount;
    final output = [List<double>.filled(outputCount, 0)];

    try {
      await isolateInterpreter.run(input, output);
    } catch (e) {
      debugPrint('TFLite static inference failed: $e');
      return null;
    }

    var bestIndex = -1;
    var bestConf = 0.0;
    final limit = min(min(output[0].length, _labels.length), outputCount);
    for (var i = 0; i < limit; i++) {
      if (!acceptsLabel(_labels[i])) continue;
      if (output[0][i] > bestConf) {
        bestConf = output[0][i];
        bestIndex = i;
      }
    }

    if (bestIndex == -1 || bestConf < minimumConfidence) return null;
    return SignResult(
      label: _labels[bestIndex],
      confidence: bestConf,
      type: type,
      isModelConfidence: true,
    );
  }

  // ── Sequence / LSTM classification ────────────────────────────────────────

  /// Call this every frame from the camera pipeline (same cadence as static).
  /// Returns a [SignResult] once enough motion frames are available and a
  /// confident match is found, otherwise returns null.
  Future<SignResult?> pushFrameAndClassify(
    List<HandLandmark> landmarks, {
    bool runModel = true,
  }) async {
    if (!isSequenceReady) return null;
    if (landmarks.length < _kLandmarks) return null;

    // Dynamic/basic-word signs need absolute hand position too. Father,
    // mother, and thank you can share similar hand shapes, so wrist-relative
    // normalization erases the most important cue.
    _frameBuffer.add(_sequenceLandmarkFeatures(landmarks));
    if (_frameBuffer.length > kSequenceFrames) {
      _frameBuffer.removeAt(0);
    }
    if (!runModel || _frameBuffer.length < _kMinimumSequenceFrames) {
      return null;
    }

    return _classifySequence();
  }

  /// Resets the frame buffer (e.g. when switching modes or on confirmed sign).
  void resetSequenceBuffer() => _frameBuffer.clear();

  Future<SignResult?> _classifySequence() async {
    final isolateInterpreter = _seqIsolateInterpreter;
    if (isolateInterpreter == null || _seqLabels.isEmpty) return null;

    // Input shape: [1, kSequenceFrames, _kSequenceFeatures]
    final input = [_sequenceInputFrames()];

    final outputCount =
        _seqOutputCount == 0 ? _seqLabels.length : _seqOutputCount;
    final output = [List<double>.filled(outputCount, 0)];

    try {
      await isolateInterpreter.run(input, output);
    } catch (e) {
      debugPrint('TFLite sequence inference failed: $e');
      return null;
    }

    var bestIndex = -1;
    var bestConf = 0.0;
    var secondConf = 0.0;
    final limit = min(output[0].length, _seqLabels.length);
    for (var i = 0; i < limit; i++) {
      final p = output[0][i];
      if (p > bestConf) {
        secondConf = bestConf;
        bestConf = p;
        bestIndex = i;
      } else if (p > secondConf) {
        secondConf = p;
      }
    }

    if (kDebugSequence) {
      final order = List<int>.generate(limit, (i) => i)
        ..sort((a, b) => output[0][b].compareTo(output[0][a]));
      debugPrint(
        'SEQ top3: ${order.take(3).map((i) => '${_seqLabels[i]} ${output[0][i].toStringAsFixed(2)}').join(' | ')}',
      );
    }

    if (bestIndex == -1 ||
        bestConf < sequenceMinimumConfidence ||
        bestConf - secondConf < 0.15) {
      return null;
    }
    return SignResult(
      label: _seqLabels[bestIndex],
      confidence: bestConf,
      type: 'sequence',
      isModelConfidence: true,
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  List<double> _normalizeLandmarks(List<HandLandmark> landmarks) {
    final wrist = landmarks[0];
    var scale = 0.0;
    for (final lm in landmarks.take(_kLandmarks)) {
      final dx = lm.x - wrist.x;
      final dy = lm.y - wrist.y;
      final dz = lm.z - wrist.z;
      scale = max(scale, sqrt(dx * dx + dy * dy + dz * dz));
    }
    scale = max(scale, 0.0001);

    final values = <double>[];
    for (final lm in landmarks.take(_kLandmarks)) {
      values.add((lm.x - wrist.x) / scale);
      values.add((lm.y - wrist.y) / scale);
      values.add((lm.z - wrist.z) / scale);
    }
    return values;
  }

  List<double> _sequenceLandmarkFeatures(List<HandLandmark> landmarks) {
    final values = <double>[];
    for (final lm in landmarks.take(_kLandmarks)) {
      values.add(lm.x);
      values.add(lm.y);
      values.add(lm.z);
    }
    return values;
  }

  List<List<double>> _sequenceInputFrames() {
    if (_frameBuffer.length >= kSequenceFrames) {
      return _frameBuffer
          .skip(_frameBuffer.length - kSequenceFrames)
          .map((frame) => List<double>.from(frame))
          .toList(growable: false);
    }

    if (_frameBuffer.isEmpty) {
      return List.generate(
        kSequenceFrames,
        (_) => List<double>.filled(_kSequenceFeatures, 0.0),
        growable: false,
      );
    }

    final firstFrame = _frameBuffer.first;
    final paddedFrames = <List<double>>[];
    while (paddedFrames.length + _frameBuffer.length < kSequenceFrames) {
      paddedFrames.add(List<double>.from(firstFrame));
    }
    paddedFrames.addAll(_frameBuffer.map((frame) => List<double>.from(frame)));
    return paddedFrames;
  }

  void close() {
    _isolateInterpreter?.close();
    _isolateInterpreter = null;
    _interpreter?.close();
    _interpreter = null;
    _outputCount = 0;
    _seqIsolateInterpreter?.close();
    _seqIsolateInterpreter = null;
    _seqInterpreter?.close();
    _seqInterpreter = null;
    _seqOutputCount = 0;
  }
}
