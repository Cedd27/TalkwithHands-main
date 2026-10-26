import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import 'sign_classifier.dart';

// ── How many frames the LSTM expects (must match train_sign_sequence_model.py)
const int kSequenceFrames = 30;
const int _kDefaultLandmarks = 21;
final RegExp _alphabetLabelPattern = RegExp(r'^[A-Z]$');

class TfliteSignClassifier {
  TfliteSignClassifier({
    this.modelAssetPath = 'data/sign_model.tflite',
    this.labelsAssetPath = 'data/sign_labels.txt',
    this.sequenceModelAssetPath = 'assets/ml/sign_sequence_classifier.tflite',
    this.sequenceLabelsAssetPath = 'assets/ml/sequence_labels.txt',
    this.minimumConfidence = 0.55,
  });

  final String modelAssetPath;
  final String labelsAssetPath;
  final String sequenceModelAssetPath;
  final String sequenceLabelsAssetPath;
  final double minimumConfidence;

  // Static (dense) model
  Interpreter? _interpreter;
  IsolateInterpreter? _isolateInterpreter;
  List<String> _labels = const [];
  int _outputCount = 0;
  int _staticLandmarkCount = _kDefaultLandmarks;

  // Sequence (LSTM) model
  Interpreter? _seqInterpreter;
  IsolateInterpreter? _seqIsolateInterpreter;
  List<String> _seqLabels = const [];
  int _seqOutputCount = 0;
  int _sequenceLandmarkCount = _kDefaultLandmarks;

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
      _interpreter =
          await Interpreter.fromAsset(modelAssetPath, options: options);
      _interpreter!.allocateTensors();
      final inputShape = _interpreter!.getInputTensor(0).shape;
      _staticLandmarkCount = _landmarkCountFromInputShape(inputShape);
      final outputShape = _interpreter!.getOutputTensor(0).shape;
      _outputCount =
          outputShape.isNotEmpty ? outputShape.last : _labels.length;
      // PERF FIX: run this interpreter on its own isolate so per-frame
      // inference never blocks the main/UI isolate (that blocking was the
      // actual cause of the tracked-hand "lagging behind" — .run() on a
      // plain Interpreter is a synchronous FFI call on whichever isolate
      // calls it).
      _isolateInterpreter =
          await IsolateInterpreter.create(address: _interpreter!.address);
      debugPrint('TFLite static model loaded (${_labels.length} labels)');
    } catch (e) {
      _labels = const [];
      _outputCount = 0;
      _staticLandmarkCount = _kDefaultLandmarks;
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
      _seqInterpreter =
          await Interpreter.fromAsset(sequenceModelAssetPath, options: options);
      _seqInterpreter!.allocateTensors();
      final inputShape = _seqInterpreter!.getInputTensor(0).shape;
      _sequenceLandmarkCount =
          _landmarkCountFromInputShape(inputShape, sequence: true);
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
      _sequenceLandmarkCount = _kDefaultLandmarks;
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
        landmarks.length < _kDefaultLandmarks) {
      return null;
    }

    final input = [_buildStaticFeatures(landmarks)];
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
  /// Returns a [SignResult] once the buffer is full and a confident match is found,
  /// otherwise returns null.
  Future<SignResult?> pushFrameAndClassify(
    List<HandLandmark> landmarks, {
    bool runModel = true,
  }) async {
    if (!isSequenceReady) return null;
    if (landmarks.length < _sequenceLandmarkCount) return null;

    // Append normalized frame to rolling buffer
    _frameBuffer.add(_flattenLandmarks(landmarks, _sequenceLandmarkCount));
    if (_frameBuffer.length > kSequenceFrames) {
      _frameBuffer.removeAt(0);
    }
    if (!runModel || _frameBuffer.length < kSequenceFrames) return null;

    return _classifySequence();
  }

  /// Resets the frame buffer (e.g. when switching modes or on confirmed sign).
  void resetSequenceBuffer() => _frameBuffer.clear();

  Future<SignResult?> _classifySequence() async {
    final isolateInterpreter = _seqIsolateInterpreter;
    if (isolateInterpreter == null || _seqLabels.isEmpty) return null;

    // Input shape: [1, kSequenceFrames, _kFeatures]
    final input = [_frameBuffer.map((f) => f).toList()];

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
    final limit = min(output[0].length, _seqLabels.length);
    for (var i = 0; i < limit; i++) {
      if (output[0][i] > bestConf) {
        bestConf = output[0][i];
        bestIndex = i;
      }
    }

    if (bestIndex == -1 || bestConf < minimumConfidence) return null;
    return SignResult(
      label: _seqLabels[bestIndex],
      confidence: bestConf,
      type: 'sequence',
      isModelConfidence: true,
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  int _landmarkCountFromInputShape(
    List<int> shape, {
    bool sequence = false,
  }) {
    if (shape.isEmpty) return _kDefaultLandmarks;
    var featureCount = shape.last;
    if (shape.length >= 2 && shape.last == 3) {
      featureCount = shape[shape.length - 2] * 3;
    }
    if (featureCount > 0 && featureCount % 3 == 0) {
      return max(_kDefaultLandmarks, featureCount ~/ 3);
    }
    if (!sequence && shape.length > 1) {
      final flattenedFeatureCount = shape.skip(1).fold<int>(
            1,
            (total, dimension) => dimension > 0 ? total * dimension : total,
          );
      if (flattenedFeatureCount > 0 && flattenedFeatureCount % 3 == 0) {
        return max(_kDefaultLandmarks, flattenedFeatureCount ~/ 3);
      }
    }
    return _kDefaultLandmarks;
  }

  // ── Camera/plugin orientation correction ───────────────────────────────────
  // CONFIRMED via on-device debug logging (holding a flat open hand, fingers
  // straight up): raw landmark x,y from hand_landmarker come out rotated 90°
  // relative to a normal upright photo — going from wrist to fingertip moved
  // almost entirely along raw x (0.16→0.64) with raw y nearly flat
  // (0.457→0.483), instead of the expected large drop in y. The training
  // data (Alphabet.zip, sign_landmarks.csv/sign_sequences.csv) all came from
  // normal upright photos/frames, so raw landmarks must be corrected BEFORE
  // being used anywhere (feature building AND the handedness heuristic).
  // Verified transform: corrected_x = raw_y; corrected_y = 1 - raw_x.
  // z is a depth value, unaffected by this planar rotation, kept as-is.
  // ADDITIONAL fix on top of the rotation correction: front-camera raw
  // sensor frames (what hand_landmarker reads) are NOT mirrored, but most
  // phone camera apps save front-camera photos MIRRORED (to match what the
  // user saw in the selfie preview) — and the training photos were very
  // likely captured/saved that way. So an extra horizontal flip is applied
  // here. If this makes things WORSE instead of better, revert _cx to
  // `lm.y` (no extra flip) — that's the one line to change back.
  double _cx(HandLandmark lm) => 1.0 - lm.y;
  double _cy(HandLandmark lm) => 1.0 - lm.x;

  // ── Static model (data/sign_model.tflite) — reverted to sign_landmark_
  // classifier.tflite (input [1,63], output [1,35]: digits 0-9 + A-Z minus
  // J, 96.68% val accuracy, trained from sign_landmarks.csv). Back to a
  // plain single hand's 21 raw landmarks, no body/second-hand blocks, no
  // handedness placement — the 46-point Alphabet.zip model produced too
  // many wrong labels, so this reverts to the better-performing CSV model.
  // Camera orientation correction (_cx/_cy) still applies — that mismatch
  // was in how the live feed is read, independent of which model is used.
  List<double> _buildStaticFeatures(List<HandLandmark> landmarks) {
    final values = <double>[];
    for (final lm in landmarks.take(21)) {
      values.add(_cx(lm));
      values.add(_cy(lm));
      values.add(lm.z);
    }
    return values;
  }

  // ── Sequence model (assets/ml/sign_sequence_classifier.tflite) ────────────
  // Confirmed shape: input [1, 30, 63], output [1, 5] (J, Z, hello, help,
  // "i love you") — trained (per sign_sequences.csv) on a SINGLE hand's 21
  // raw landmarks per frame, no wrist normalization, no mirroring. This is
  // a DIFFERENT, older pipeline than the 46-point static model above, so it
  // keeps its own simple flatten — do not change this to 46-point until the
  // sequence model itself is retrained on 46-point data. Same camera
  // orientation correction (_cx/_cy) applied here too — that mismatch was in
  // how the live feed is read, not specific to one model.
  List<double> _flattenLandmarks(
    List<HandLandmark> landmarks,
    int landmarkCount,
  ) {
    final values = <double>[];
    for (final lm in landmarks.take(landmarkCount)) {
      values.add(_cx(lm));
      values.add(_cy(lm));
      values.add(lm.z);
    }
    return values;
  }

  void close() {
    _isolateInterpreter?.close();
    _isolateInterpreter = null;
    _interpreter?.close();
    _interpreter = null;
    _outputCount = 0;
    _staticLandmarkCount = _kDefaultLandmarks;
    _seqIsolateInterpreter?.close();
    _seqIsolateInterpreter = null;
    _seqInterpreter?.close();
    _seqInterpreter = null;
    _seqOutputCount = 0;
    _sequenceLandmarkCount = _kDefaultLandmarks;
  }
}