import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hand_landmarker/hand_landmarker.dart' as mp_hand;
import 'package:permission_handler/permission_handler.dart';
import 'data_collection_screen.dart';
import '../classifiers/sign_classifier.dart';
import '../classifiers/tflite_sign_classifier.dart';
import '../painters/landmark_painter.dart';
import '../ui/background_music_region.dart';
import '../services/tts_service.dart';

const List<String> kDict = [
  'hello',
  'help',
  'happy',
  'have',
  'here',
  'home',
  'how',
  'hurry',
  'thank you',
  'thanks',
  'that',
  'the',
  'this',
  'time',
  'today',
  'together',
  'i love you',
  'i',
  'im',
  'is',
  'it',
  'in',
  'yes',
  'you',
  'your',
  'no',
  'not',
  'now',
  'need',
  'next',
  'nice',
  'name',
  'please',
  'play',
  'pretty',
  'problem',
  'pain',
  'sorry',
  'stop',
  'school',
  'see',
  'more',
  'me',
  'my',
  'good',
  'go',
  'give',
  'get',
  'bad',
  'boy',
  'bye',
  'bathroom',
  'want',
  'water',
  'where',
  'what',
  'when',
  'who',
  'why',
  'with',
  'work',
  'eat',
  'every',
  'come',
  'can',
  'could',
  'call',
  'day',
  'dad',
  'do',
  'done',
  'down',
  'drink',
  'friend',
  'fine',
  'feel',
  'food',
  'fun',
  'find',
  'love',
  'learn',
  'late',
  'later',
  'open',
  'out',
  'right',
  'read',
  'run',
  'ready',
];

const Set<String> _highRiskWordLabels = {'i love you'};

enum DetectionMode { words, az, num, motion }

enum MotionCategory { words, az, num }

enum CaptureKind { image, video }

class SignDetectorScreen extends StatefulWidget {
  final DetectionMode initialMode;
  final bool lockMode;
  final CaptureKind captureKind;
  final String title;

  const SignDetectorScreen({
    super.key,
    this.initialMode = DetectionMode.words,
    this.lockMode = false,
    this.captureKind = CaptureKind.video,
    this.title = 'SIGN TO TEXT',
  });

  @override
  State<SignDetectorScreen> createState() => _SignDetectorScreenState();
}

class _SignDetectorScreenState extends State<SignDetectorScreen>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  bool _cameraInitialized = false;
  bool _camPaused = false;
  bool _processing = false;
  bool _streaming = false;
  int _frameCounter = 0;
  DateTime _lastInferenceAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastUiUpdateAt = DateTime.fromMillisecondsSinceEpoch(0);

  mp_hand.HandLandmarkerPlugin? _handLandmarker;
  final SignClassifier _classifier = SignClassifier();
  final TfliteSignClassifier _tfliteClassifier = TfliteSignClassifier();
  final TtsService _tts = TtsService();
  static const Set<String> _ruleFirstAlphabetLabels = {
    'G',
    'H',
    'I',
    'J',
    'L',
    'R',
    'S',
    'U',
    'V',
    'W',
    'Y',
    'Z',
  };

  List<HandLandmark>? _handLandmarks;
  List<List<HandLandmark>>? _handsLandmarks;
  List<List<HandLandmark>>? _smoothedHandsLandmarks;
  SignResult? _currentHit;
  int _holdFrames = 0;
  Timer? _startCountdownTimer;
  bool _detectionArmed = false;
  int _startCountdown = 0;
  static const int _prepareSeconds = 5;
  final List<SignResult> _captureHits = [];
  String? _captureMessage;
  // Require 8 consistent frames before confirming — prevents mid-transition false triggers
  // At ~3 detections/sec on TECNO KM4k this means ~2.5 seconds of holding the sign
  static const int _holdNeed = 4;
  // Process every 2nd frame and let the minimum inference gap cap the load.
  static const int _processEveryNFrames = 2;
  // Minimum 60ms between inference attempts (~16fps cap).
  static const Duration _minInferenceGap = Duration(milliseconds: 60);
  // UI refreshes at most every 40ms (~25fps).
  static const Duration _minUiGap = Duration(milliseconds: 40);
  // Trust the newest detected position more so the overlay trails less.
  static const double _landmarkSmoothing = 0.7;

  late DetectionMode _mode;
  MotionCategory _motionCategory = MotionCategory.words;
  List<String> _words = [];
  String _curWord = '';
  List<String> _history = [];

  bool _loading = true;
  String _loadText = 'Initializing...';

  bool get _isAndroid => !kIsWeb && Platform.isAndroid;

  Size? get _rawPreviewSize => _cameraController?.value.previewSize;

  Size? get _displayPreviewSize {
    final previewSize = _rawPreviewSize;
    if (previewSize == null) return null;
    return Size(previewSize.height, previewSize.width);
  }

  bool get _usesVideoCapture => widget.captureKind == CaptureKind.video;

  bool get _isLockedImagePractice => widget.lockMode && !_usesVideoCapture;

  bool get _isLockedWordPractice =>
      widget.lockMode && _mode == DetectionMode.words;

  String get _startCaptureLabel =>
      _usesVideoCapture ? 'Start Video Capture' : 'Start Capture';

  String get _stopCaptureLabel =>
      _usesVideoCapture ? 'Stop Video Capture' : 'Stop Capture';

  String get _activeCaptureText =>
      _usesVideoCapture ? 'Recording video...' : 'Capturing images...';

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  Future<void> _init() async {
    await _tts.init();
    await _tfliteClassifier.load();
    if (!_isAndroid) {
      setState(() {
        _loadText =
            'MediaPipe hand tracking is currently configured for Android only.';
        _loading = false;
      });
      return;
    }
    setState(() => _loadText = 'Loading hand tracker...');
    _handLandmarker = mp_hand.HandLandmarkerPlugin.create(
      numHands: 2,
      minHandDetectionConfidence: 0.55,
      // GPU is the faster path for this plugin on supported Android devices.
      delegate: mp_hand.HandLandmarkerDelegate.gpu,
    );
    await _requestCameraPermission();
  }

  Future<void> _requestCameraPermission() async {
    setState(() => _loadText = 'Requesting camera permission...');
    final status = await Permission.camera.request();
    if (status.isGranted) {
      await _initCamera();
    } else {
      setState(() {
        _loadText = 'Camera permission denied. Please grant it in Settings.';
        _loading = false;
      });
    }
  }

  Future<void> _initCamera() async {
    setState(() => _loadText = 'Starting camera...');
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _loadText = 'No cameras found.';
          _loading = false;
        });
        return;
      }

      final camera = cameras.firstWhere(
        (item) => item.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        camera,
        // PERF FIX 9: Use medium resolution.
        // 'low' sounds faster but can actually hurt MediaPipe accuracy,
        // causing MORE retries and lag. Medium gives cleaner landmark data
        // with fewer missed frames. If still laggy, switch back to low.
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.yuv420
            : ImageFormatGroup.bgra8888,
      );

      await controller.initialize();
      await _cameraController?.dispose();
      _cameraController = controller;

      setState(() {
        _cameraInitialized = true;
        _loading = false;
      });

      // Leave the preview smooth. Start the analyzer stream only while
      // a sign capture is active.
    } catch (error) {
      setState(() {
        _loadText = 'Camera error: $error';
        _loading = false;
      });
    }
  }

  // Sync callback — never blocks the camera hardware buffer.
  // Detection is fire-and-forget via unawaited _processFrame().
  void _onCameraFrame(CameraImage image) {
    if (_camPaused ||
        !_detectionArmed ||
        _startCountdown > 0 ||
        _processing ||
        !_cameraInitialized ||
        _cameraController == null) {
      return;
    }
    _frameCounter++;
    if (_frameCounter % _processEveryNFrames != 0) {
      return;
    }
    final now = DateTime.now();
    if (now.difference(_lastInferenceAt) < _minInferenceGap) {
      return;
    }
    _lastInferenceAt = now;
    _processFrame(image, now); // fire-and-forget
  }

  Future<void> _processFrame(CameraImage image, DateTime now) async {
    _processing = true;
    try {
      final controller = _cameraController!;
      final sensorOrientation = controller.description.sensorOrientation;

      List<List<HandLandmark>>? handsLandmarks;
      try {
        if (image.planes.length >= 3) {
          final handLandmarker = _handLandmarker;
          if (handLandmarker == null) return;
          final detectedHands = handLandmarker.detect(image, sensorOrientation);
          final maxHands = _mode == DetectionMode.words ||
                  (_mode == DetectionMode.motion &&
                      _motionCategory == MotionCategory.words)
              ? 2
              : 1;
          handsLandmarks = detectedHands.isNotEmpty
              ? detectedHands
                  .take(maxHands)
                  .map((hand) => _mapHandLandmarks(hand.landmarks))
                  .toList(growable: false)
              : null;
          if (handsLandmarks == null) {
            _smoothedHandsLandmarks = null;
          }
        } else {
          debugPrint(
            'Skipping hand detection: expected 3 image planes, got ${image.planes.length}.',
          );
        }
      } catch (error) {
        debugPrint('Hand detection error: $error');
      }

      final displayHandsLandmarks =
          handsLandmarks == null ? null : _smoothHandsLandmarks(handsLandmarks);
      final displayHandLandmarks =
          displayHandsLandmarks == null || displayHandsLandmarks.isEmpty
              ? null
              : displayHandsLandmarks.first;
      final primaryHandLandmarks =
          handsLandmarks == null || handsLandmarks.isEmpty
              ? null
              : handsLandmarks.first;

      SignResult? hit;
      final canClassify = _detectionArmed && _startCountdown == 0;
      if (canClassify && primaryHandLandmarks != null) {
        hit = await _classifyCurrentFrame(primaryHandLandmarks, handsLandmarks);
        _trackCaptureHit(hit);
      }
      if (!canClassify) {
        _resetHoldState();
      }

      if (!mounted) return;

      // PERF FIX: Only call setState when something VISIBLE actually changed.
      // Avoid setState when hit label is same and hand presence hasn't changed.
      final visibleHit = hit ?? _currentHit;
      final hitChanged = visibleHit?.label != _currentHit?.label;
      final handPresenceChanged =
          (displayHandLandmarks == null) != (_handLandmarks == null);
      final uiTimerExpired = now.difference(_lastUiUpdateAt) >= _minUiGap;

      // Always update internal state
      _handLandmarks = displayHandLandmarks;
      _handsLandmarks = displayHandsLandmarks;
      _currentHit = visibleHit;

      // Only trigger rebuild when needed
      if (hitChanged || handPresenceChanged || uiTimerExpired) {
        _lastUiUpdateAt = now;
        if (mounted) setState(() {});
      }

      if (canClassify) {
        _holdFrames = _captureHits.length.clamp(0, _holdNeed);
      }
    } finally {
      _processing = false;
    }
  }

  Future<SignResult?> _classifyCurrentFrame(
    List<HandLandmark> primaryHandLandmarks,
    List<List<HandLandmark>>? handsLandmarks,
  ) async {
    SignResult? hit;
    switch (_mode) {
      case DetectionMode.az:
        final ruleHit = _classifier.classifyAlphabet(primaryHandLandmarks);
        final sequenceHit = await _tfliteClassifier.pushFrameAndClassify(
          primaryHandLandmarks,
        );
        final tfliteHit = await _tfliteClassifier.classifyAlphabet(
          primaryHandLandmarks,
        );
        hit = _chooseAlphabetHit(ruleHit, tfliteHit, sequenceHit);
        break;
      case DetectionMode.num:
        // Sequence model handles the motion numbers 10-20;
        // fall back to the static classifiers for 0-9.
        final seqHit = await _tfliteClassifier.pushFrameAndClassify(
          primaryHandLandmarks,
        );
        final seqNumber = seqHit == null ? null : int.tryParse(seqHit.label);
        if (seqHit != null &&
            seqNumber != null &&
            seqNumber >= 10 &&
            seqNumber <= 20) {
          hit = SignResult(
            label: seqHit.label,
            confidence: seqHit.confidence,
            type: 'number',
            isModelConfidence: true,
          );
        } else {
          final modelHit =
              await _tfliteClassifier.classifyNumber(primaryHandLandmarks);
          hit = modelHit?.label == '2' &&
                  !_classifier.looksLikeNumberTwo(primaryHandLandmarks)
              ? null
              : modelHit ?? _classifier.classifyNumber(primaryHandLandmarks);
        }
        break;
      case DetectionMode.words:
        final sequenceHit = await _tfliteClassifier.pushFrameAndClassify(
          primaryHandLandmarks,
        );
        hit = _wordHitFromSequence(sequenceHit, primaryHandLandmarks);
        break;
      case DetectionMode.motion:
        hit = await _classifyMotionFrame(primaryHandLandmarks, handsLandmarks);
        break;
    }
    return _acceptedHit(hit);
  }

  Future<SignResult?> _classifyMotionFrame(
    List<HandLandmark> primaryHandLandmarks,
    List<List<HandLandmark>>? handsLandmarks,
  ) async {
    switch (_motionCategory) {
      case MotionCategory.az:
        final sequenceHit = await _tfliteClassifier.pushFrameAndClassify(
          primaryHandLandmarks,
        );
        if (sequenceHit != null &&
            (sequenceHit.label == 'J' || sequenceHit.label == 'Z')) {
          return SignResult(
            label: sequenceHit.label,
            confidence: sequenceHit.confidence,
            type: 'alphabet',
            isModelConfidence: sequenceHit.isModelConfidence,
          );
        }
        return _classifier.classifyMotionAlphabet(primaryHandLandmarks);
      case MotionCategory.num:
        final sequenceHit = await _tfliteClassifier.pushFrameAndClassify(
          primaryHandLandmarks,
        );
        final sequenceNumber =
            sequenceHit == null ? null : int.tryParse(sequenceHit.label);
        if (sequenceHit != null &&
            sequenceNumber != null &&
            sequenceNumber >= 10 &&
            sequenceNumber <= 20) {
          return SignResult(
            label: sequenceHit.label,
            confidence: sequenceHit.confidence,
            type: 'number',
            isModelConfidence: sequenceHit.isModelConfidence,
          );
        }
        return _classifier.classifyMotionNumber(primaryHandLandmarks);
      case MotionCategory.words:
        final sequenceHit = await _tfliteClassifier.pushFrameAndClassify(
          primaryHandLandmarks,
        );
        return _wordHitFromSequence(sequenceHit, primaryHandLandmarks);
    }
  }

  bool _alphabetLabel(String label) => RegExp(r'^[A-Z]$').hasMatch(label);

  SignResult? _wordHitFromSequence(
    SignResult? sequenceHit,
    List<HandLandmark> landmarks,
  ) {
    if (sequenceHit == null ||
        _alphabetLabel(sequenceHit.label) ||
        int.tryParse(sequenceHit.label) != null) {
      return null;
    }
    final rawLabel = sequenceHit.label.toLowerCase();
    if (rawLabel == 'i love you' && !_looksLikeILoveYou(landmarks)) return null;
    return SignResult(
      label: sequenceHit.label,
      confidence: sequenceHit.confidence,
      type: 'word',
      isModelConfidence: sequenceHit.isModelConfidence,
    );
  }

  bool _looksLikeILoveYou(List<HandLandmark> lm) {
    if (lm.length < 21) return false;
    final indexUp = lm[8].y < lm[6].y;
    final middleUp = lm[12].y < lm[10].y;
    final ringUp = lm[16].y < lm[14].y;
    final pinkyUp = lm[20].y < lm[18].y;
    final thumbAway =
        (lm[4].x - lm[9].x).abs() > (lm[5].x - lm[17].x).abs() * 0.45;
    return indexUp && pinkyUp && thumbAway && !middleUp && !ringUp;
  }

  bool _looksLikeFather(List<HandLandmark> lm) {
    if (lm.length < 21) return false;
    final indexUp = lm[8].y < lm[6].y;
    final middleUp = lm[12].y < lm[10].y;
    final ringUp = lm[16].y < lm[14].y;
    final pinkyUp = lm[20].y < lm[18].y;
    final thumbAway =
        (lm[4].x - lm[9].x).abs() > (lm[5].x - lm[17].x).abs() * 0.35;
    final fingertipsHigh = lm[8].y < 0.42 && lm[12].y < 0.42 && lm[16].y < 0.45;
    final verticalPalm = (lm[9].y - lm[0].y).abs() > (lm[9].x - lm[0].x).abs();
    return indexUp &&
        middleUp &&
        ringUp &&
        pinkyUp &&
        thumbAway &&
        fingertipsHigh &&
        verticalPalm;
  }

  SignResult? _chooseAlphabetHit(
    SignResult? ruleHit,
    SignResult? tfliteHit,
    SignResult? sequenceHit,
  ) {
    if (sequenceHit != null &&
        (sequenceHit.label == 'J' || sequenceHit.label == 'Z')) {
      return SignResult(
        label: sequenceHit.label,
        confidence: sequenceHit.confidence,
        type: 'alphabet',
        isModelConfidence: sequenceHit.isModelConfidence,
      );
    }
    if (ruleHit != null &&
        tfliteHit != null &&
        ((ruleHit.label == 'U' && tfliteHit.label == 'H') ||
            (ruleHit.label == 'P' && tfliteHit.label == 'Q'))) {
      return ruleHit;
    }
    if (tfliteHit != null) return tfliteHit;
    if (ruleHit != null && _ruleFirstAlphabetLabels.contains(ruleHit.label)) {
      return ruleHit;
    }
    return ruleHit;
  }

  SignResult? _acceptedHit(SignResult? hit) {
    if (hit == null) return null;
    switch (_mode) {
      case DetectionMode.az:
        return RegExp(r'^[A-Z]$').hasMatch(hit.label) ? hit : null;
      case DetectionMode.num:
        final number = int.tryParse(hit.label);
        return number != null && number >= 0 && number <= 20 ? hit : null;
      case DetectionMode.words:
        final isLetter = RegExp(r'^[A-Z]$').hasMatch(hit.label);
        final number = int.tryParse(hit.label);
        final isPracticeNumber = number != null && number >= 0 && number <= 20;
        return !isLetter && !isPracticeNumber ? hit : null;
      case DetectionMode.motion:
        switch (_motionCategory) {
          case MotionCategory.az:
            return RegExp(r'^[A-Z]$').hasMatch(hit.label) ? hit : null;
          case MotionCategory.num:
            final number = int.tryParse(hit.label);
            return number != null && number >= 0 && number <= 20 ? hit : null;
          case MotionCategory.words:
            final isLetter = RegExp(r'^[A-Z]$').hasMatch(hit.label);
            final number = int.tryParse(hit.label);
            return !isLetter && number == null ? hit : null;
        }
    }
  }

  Future<void> _startImageStream() async {
    final controller = _cameraController;
    if (controller == null || _streaming || !controller.value.isInitialized) {
      return;
    }
    await controller.startImageStream(_onCameraFrame);
    _streaming = true;
  }

  Future<void> _stopImageStream() async {
    final controller = _cameraController;
    if (controller == null || !_streaming) return;
    try {
      await controller.stopImageStream();
    } catch (error) {
      debugPrint('Camera stream stop ignored: $error');
    } finally {
      _streaming = false;
      _processing = false;
    }
  }

  Future<void> _setCameraPaused(bool paused) async {
    if (_camPaused == paused) return;
    setState(() => _camPaused = paused);
    if (paused) {
      await _stopImageStream();
    } else if (_detectionArmed && _startCountdown == 0) {
      _lastInferenceAt = DateTime.fromMillisecondsSinceEpoch(0);
      await _startImageStream();
    }
  }

  List<HandLandmark> _mapHandLandmarks(List<mp_hand.Landmark> landmarks) {
    return landmarks
        .map((landmark) => HandLandmark(landmark.x, landmark.y, landmark.z))
        .toList(growable: false);
  }

  List<List<HandLandmark>> _smoothHandsLandmarks(
    List<List<HandLandmark>> hands,
  ) {
    final previousHands = _smoothedHandsLandmarks;
    if (previousHands == null || previousHands.length != hands.length) {
      _smoothedHandsLandmarks = hands
          .map((landmarks) => List<HandLandmark>.from(landmarks))
          .toList(growable: false);
      return _smoothedHandsLandmarks!;
    }

    final smoothedHands = <List<HandLandmark>>[];
    for (var handIndex = 0; handIndex < hands.length; handIndex++) {
      final landmarks = hands[handIndex];
      final previous = previousHands[handIndex];
      if (previous.length != landmarks.length) {
        smoothedHands.add(List<HandLandmark>.from(landmarks));
        continue;
      }

      final smoothed = <HandLandmark>[];
      for (var i = 0; i < landmarks.length; i++) {
        final current = landmarks[i];
        final prior = previous[i];
        smoothed.add(
          HandLandmark(
            _lerp(prior.x, current.x, _landmarkSmoothing),
            _lerp(prior.y, current.y, _landmarkSmoothing),
            // PERF FIX 8: Skip Z-axis smoothing — Z is not used by the
            // classifier so there's no reason to lerp it every frame.
            current.z,
          ),
        );
      }
      smoothedHands.add(smoothed);
    }
    _smoothedHandsLandmarks = smoothedHands;
    return smoothedHands;
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  void _resetHoldState() {
    _holdFrames = 0;
  }

  void _trackCaptureHit(SignResult? hit) {
    if (hit == null) return;
    final minimumConfidence = (hit.label == 'J' || hit.label == 'Z')
        ? 0.70
        : (hit.type == 'word' && hit.isModelConfidence ? 0.25 : 0.76);
    if (hit.confidence < minimumConfidence) return;
    _captureHits.add(hit);
    if (_captureHits.length > 36) {
      _captureHits.removeAt(0);
    }
  }

  SignResult? _bestCapturedHit() {
    if (_captureHits.isEmpty) return null;

    final grouped = <String, List<SignResult>>{};
    for (final hit in _captureHits) {
      grouped.putIfAbsent(hit.label, () => []).add(hit);
    }

    SignResult? best;
    double bestScore = 0;
    for (final entry in grouped.entries) {
      final hits = entry.value;
      final topHit = hits.reduce(
        (a, b) => a.confidence >= b.confidence ? a : b,
      );
      final isModelWord = topHit.type == 'word' && topHit.isModelConfidence;
      // A word must be seen in several frames; one lucky frame is not enough.
      if (isModelWord && hits.length < 3) continue;
      final meanConfidence =
          hits.map((h) => h.confidence).reduce((a, b) => a + b) / hits.length;
      // Votes weighted by confidence, so the label seen most often wins.
      final score = isModelWord
          ? hits.length * meanConfidence
          : topHit.confidence +
              (hits.length / 6).clamp(0.0, 0.18) +
              (topHit.isModelConfidence ? 0.04 : 0.0);
      if (score > bestScore) {
        bestScore = score;
        best = topHit;
      }
    }
    if (best != null) return best;
    final onlyModelWords = _captureHits.every(
      (h) => h.type == 'word' && h.isModelConfidence,
    );
    if (onlyModelWords) return null; // better "try again" than a wrong word
    return _captureHits.reduce((a, b) => a.confidence >= b.confidence ? a : b);
  }

  void _startSigningCountdown() {
    _startCountdownTimer?.cancel();
    unawaited(_stopImageStream());
    setState(() {
      _detectionArmed = false;
      _startCountdown = _prepareSeconds;
      _currentHit = null;
      _handLandmarks = null;
      _handsLandmarks = null;
      _smoothedHandsLandmarks = null;
      _captureHits.clear();
      _captureMessage = null;
      _resetHoldState();
      _classifier.reset();
      _tfliteClassifier.resetSequenceBuffer();
    });

    _startCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _startCountdown--;
        if (_startCountdown <= 0) {
          _startCountdown = 0;
          _detectionArmed = true;
          _lastInferenceAt = DateTime.fromMillisecondsSinceEpoch(0);
          _frameCounter = 0;
          unawaited(_startImageStream());
          timer.cancel();
        }
      });
    });
  }

  void _finishSigningCapture() {
    if (!_detectionArmed) return;
    unawaited(_stopImageStream());
    final best = _bestCapturedHit();
    setState(() {
      _detectionArmed = false;
      _startCountdown = 0;
      _currentHit = best;
      _handLandmarks = null;
      _handsLandmarks = null;
      _smoothedHandsLandmarks = null;
      _captureMessage =
          best == null ? 'No clear sign detected. Try capturing again.' : null;
      _captureHits.clear();
      _resetHoldState();
      _classifier.reset();
      _tfliteClassifier.resetSequenceBuffer();
    });
    if (best != null) {
      _onConfirm(best.label);
    }
  }

  void _onConfirm(String label) {
    _tfliteClassifier
        .resetSequenceBuffer(); // reset LSTM frame buffer on confirm
    setState(() {
      if (_mode == DetectionMode.az ||
          (_mode == DetectionMode.motion &&
              _motionCategory == MotionCategory.az)) {
        final isLetterOrNum = RegExp(r'^[A-Z0-9]+$').hasMatch(label);
        if (isLetterOrNum) {
          _curWord += label;
          if (_curWord.length > 40) {
            _curWord = _curWord.substring(_curWord.length - 40);
          }
          _addHistory(label);
        } else {
          _commitWord(label);
        }
      } else {
        _commitWord(label);
      }
    });
    _tts.speak(label);
  }

  void _commitWord(String word) {
    _words.add(word);
    if (_words.length > 40) {
      _words.removeRange(0, _words.length - 40);
    }
    _curWord = '';
    _addHistory(word);
  }

  void _addHistory(String label) {
    _history.insert(0, label);
    if (_history.length > 7) {
      _history.removeLast();
    }
  }

  String _buildSentence() {
    return [..._words, if (_curWord.isNotEmpty) _curWord].join(' ');
  }

  String _compactSentence(String sentence) {
    const maxChars = 120;
    if (sentence.length <= maxChars) return sentence;
    return '...${sentence.substring(sentence.length - maxChars)}';
  }

  List<String> _getSuggestions() {
    final spellingMode = _mode == DetectionMode.az ||
        (_mode == DetectionMode.motion && _motionCategory == MotionCategory.az);
    if (!spellingMode || _curWord.isEmpty) return [];
    final prefix = _curWord.toLowerCase();
    return kDict.where((word) => word.startsWith(prefix)).take(6).toList();
  }

  void _setMode(DetectionMode mode) {
    if (widget.lockMode && mode != widget.initialMode) return;
    unawaited(_stopImageStream());
    setState(() {
      _mode = mode;
      _curWord = '';
      _captureHits.clear();
      _captureMessage = null;
      _detectionArmed = false;
      _startCountdown = 0;
      _startCountdownTimer?.cancel();
      _classifier.reset();
      _tfliteClassifier.resetSequenceBuffer();
      _holdFrames = 0;
      _currentHit = null;
      _handLandmarks = null;
      _handsLandmarks = null;
      _smoothedHandsLandmarks = null;
    });
  }

  void _setMotionCategory(MotionCategory category) {
    unawaited(_stopImageStream());
    setState(() {
      _motionCategory = category;
      _curWord = '';
      _captureHits.clear();
      _captureMessage = null;
      _detectionArmed = false;
      _startCountdown = 0;
      _startCountdownTimer?.cancel();
      _classifier.reset();
      _tfliteClassifier.resetSequenceBuffer();
      _resetHoldState();
      _currentHit = null;
      _handLandmarks = null;
      _handsLandmarks = null;
      _smoothedHandsLandmarks = null;
    });
  }

  void _deleteLast() {
    setState(() {
      if (_curWord.isNotEmpty) {
        _curWord = _curWord.substring(0, _curWord.length - 1);
      } else if (_words.isNotEmpty) {
        _words.removeLast();
      }
    });
  }

  void _addSpace() {
    if (_curWord.isEmpty) return;
    setState(() => _commitWord(_curWord));
  }

  void _clearAll() {
    unawaited(_stopImageStream());
    setState(() {
      _words = [];
      _curWord = '';
      _history = [];
      _currentHit = null;
      _handLandmarks = null;
      _handsLandmarks = null;
      _smoothedHandsLandmarks = null;
      _captureMessage = null;
      _captureHits.clear();
      _detectionArmed = false;
      _startCountdown = 0;
      _startCountdownTimer?.cancel();
      _resetHoldState();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _cameraController;
    if (controller == null) return;

    if (state == AppLifecycleState.inactive) {
      _camPaused = true;
      _streaming = false;
      _detectionArmed = false;
      _startCountdown = 0;
      _startCountdownTimer?.cancel();
      controller.dispose();
      _cameraController = null;
      _cameraInitialized = false;
    } else if (state == AppLifecycleState.resumed && _isAndroid) {
      _camPaused = false;
      _initCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _startCountdownTimer?.cancel();
    _stopImageStream();
    _cameraController?.dispose();
    _handLandmarker?.dispose();
    _tfliteClassifier.close();
    _tts.dispose();
    super.dispose();
  }

  static const Color kTeal = Color(0xFF00E5CC);
  static const Color kBg = Color(0xFF050505);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: BackgroundMusicRegion(
        track: null,
        showToggle: false,
        child: Stack(
          children: [
            if (_cameraInitialized && _cameraController != null)
              _buildCameraPreview()
            else
              Image.asset(
                'assets/NEW BACKGROUND/new sign to text.png',
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              ),
            if (!_isLockedImagePractice)
              Positioned(
                top: MediaQuery.of(context).padding.top + 54,
                right: 14,
                child: _buildHistory(),
              ),
            if (!_isLockedImagePractice)
              Positioned(
                top: MediaQuery.of(context).padding.top + 54,
                left: 14,
                child: _buildBadge(),
              ),
            Positioned(top: 0, left: 0, right: 0, child: _buildTopBar()),
            if (!_loading &&
                !_detectionArmed &&
                _startCountdown == 0 &&
                _currentHit != null)
              Positioned(
                top: MediaQuery.of(context).padding.top + 92,
                left: 18,
                right: 18,
                child: _buildResultText(),
              ),
            if (!_isLockedImagePractice)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildBottomPanel(),
              ),
            if (_isLockedImagePractice && _detectionArmed)
              Positioned(
                left: 0,
                right: 0,
                top: MediaQuery.of(context).size.height * 0.56,
                child: Center(child: _buildCenteredStopCapture()),
              ),
            if (_isLockedImagePractice &&
                !_loading &&
                !_detectionArmed &&
                _startCountdown == 0 &&
                _currentHit != null)
              Positioned(
                left: 0,
                right: 0,
                top: MediaQuery.of(context).size.height * 0.56,
                child: Center(child: _buildCenteredStartCapture()),
              ),
            if (!_loading &&
                !_detectionArmed &&
                (_buildSentence().isEmpty ||
                    _startCountdown > 0 ||
                    _captureMessage != null))
              _buildStartOverlay(),
            if (_loading) _buildLoadingOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildResultText() {
    final hit = _currentHit;
    if (hit == null) return const SizedBox.shrink();
    final accuracy = '${(hit.confidence.clamp(0.0, 1.0) * 100).round()}%';

    return IgnorePointer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            hit.label.toUpperCase(),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: kTeal,
              fontSize: 34,
              fontWeight: FontWeight.w900,
              height: 1.05,
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.9),
                  blurRadius: 14,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
          ),
          if (_isLockedImagePractice) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xD0000000),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: kTeal, width: 1.2),
              ),
              child: Text(
                'Accuracy: $accuracy',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCenteredStopCapture() {
    return GestureDetector(
      onTap: _finishSigningCapture,
      child: Container(
        width: 166,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFFF4D6A),
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF4D6A).withValues(alpha: 0.36),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.stop_rounded, color: Colors.white, size: 20),
            SizedBox(width: 6),
            Text(
              'Stop Capture',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenteredStartCapture() {
    return GestureDetector(
      onTap: _startSigningCountdown,
      child: Container(
        width: 166,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: kTeal,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: kTeal.withValues(alpha: 0.36),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.play_arrow_rounded, color: Colors.black, size: 21),
            SizedBox(width: 6),
            Text(
              'Start Capture',
              style: TextStyle(
                color: Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraPreview() {
    final controller = _cameraController;
    final rawPreviewSize = _rawPreviewSize;
    final displayPreviewSize = _displayPreviewSize;
    if (controller == null ||
        rawPreviewSize == null ||
        displayPreviewSize == null) {
      return const SizedBox.expand();
    }

    return SizedBox.expand(
      child: ClipRect(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: displayPreviewSize.width,
            height: displayPreviewSize.height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                RepaintBoundary(child: CameraPreview(controller)),
                IgnorePointer(
                  child: CustomPaint(
                    painter: LandmarkPainter(
                      handsLandmarks: _handsLandmarks,
                      previewSize: rawPreviewSize,
                      lensDirection: controller.description.lensDirection,
                      sensorOrientation:
                          controller.description.sensorOrientation,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 14,
        right: 14,
        bottom: 10,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xB3000000), Colors.transparent],
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              width: 44,
              height: 44,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF39D8E8), Color(0xFF1387C9)],
                ),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.8),
                  width: 1.4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: kTeal.withValues(alpha: 0.5),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          Expanded(
            child: Text(
              widget.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _TopBtn(
            label: 'Collect',
            active: false,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DataCollectionScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge() {
    final hit = _currentHit;
    if (_handLandmarks == null) return const SizedBox.shrink();

    var color = const Color(0xFF333333);
    var label = '...';
    var typeLabel = 'hand visible';
    var percent = '';
    var confidenceBar = 0.0;
    var holdBar = 0.0;

    if (hit != null) {
      final confidence = hit.confidence;
      color = confidence > 0.82
          ? kTeal
          : confidence > 0.70
              ? const Color(0xFFFFCC00)
              : const Color(0xFFFF7744);
      label = hit.label;
      typeLabel = _mode == DetectionMode.motion
          ? 'motion ${_motionCategoryLabel()}'
          : _mode == DetectionMode.az
              ? 'alphabet'
              : _mode == DetectionMode.num
                  ? 'number'
                  : 'word / phrase';
      percent = hit.isModelConfidence
          ? 'Accuracy: ${(confidence * 100).round()}%'
          : 'Rule match';
      confidenceBar = confidence;
      holdBar = _holdFrames / _holdNeed;
    }

    final badgeWidth = MediaQuery.sizeOf(context).width * 0.25;

    return Container(
      width: badgeWidth,
      constraints: BoxConstraints(minWidth: badgeWidth),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xD0000000),
        border: Border.all(color: color, width: 2),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            typeLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0x66FFFFFF),
              fontSize: 9,
              letterSpacing: 0.3,
            ),
          ),
          if (percent.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              percent,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0x88FFFFFF), fontSize: 9),
            ),
            const SizedBox(height: 3),
            if (hit != null && hit.isModelConfidence)
              _MiniBar(value: confidenceBar, color: color),
          ],
          const SizedBox(height: 4),
          _MiniBar(value: holdBar, color: const Color(0xFFFFCC00)),
          const SizedBox(height: 2),
          Text(
            _detectionArmed ? 'press $_stopCaptureLabel when done' : 'ready',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0x44FFFFFF), fontSize: 8),
          ),
        ],
      ),
    );
  }

  String _motionCategoryLabel() {
    switch (_motionCategory) {
      case MotionCategory.words:
        return 'words';
      case MotionCategory.az:
        return 'A-Z';
      case MotionCategory.num:
        return '0-20';
    }
  }

  Widget _buildHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < _history.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color:
                    i == 0 ? const Color(0x2E00E5CC) : const Color(0x99000000),
                border: Border.all(
                  color: i == 0
                      ? const Color(0x8C00E5CC)
                      : const Color(0x26FFFFFF),
                  width: 0.5,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                _history[i],
                style: TextStyle(
                  color: i == 0 ? kTeal : const Color(0x73FFFFFF),
                  fontSize: i == 0 ? 13 : 12,
                  fontWeight: i == 0 ? FontWeight.w700 : FontWeight.normal,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBottomPanel() {
    final sentence = _buildSentence();
    final visibleSentence = _compactSentence(sentence);
    final suggestions = _getSuggestions();
    final spellingMode = _mode == DetectionMode.az ||
        (_mode == DetectionMode.motion && _motionCategory == MotionCategory.az);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xE0000000),
        border: Border(top: BorderSide(color: Color(0x14FFFFFF), width: 1)),
      ),
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!widget.lockMode) ...[
            Row(
              children: [
                Expanded(
                  child: _ModeBtn(
                    label: 'Words',
                    active: _mode == DetectionMode.words,
                    onTap: () => _setMode(DetectionMode.words),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _ModeBtn(
                    label: 'A-Z',
                    active: _mode == DetectionMode.az,
                    onTap: () => _setMode(DetectionMode.az),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _ModeBtn(
                    label: 'Num',
                    active: _mode == DetectionMode.num,
                    onTap: () => _setMode(DetectionMode.num),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.sizeOf(context).height * 0.25,
            ),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 96),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
              decoration: BoxDecoration(
                color: const Color(0x0DFFFFFF),
                border: Border.all(color: const Color(0x4D00E5CC), width: 0.5),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      sentence.isEmpty
                          ? (_detectionArmed
                              ? '$_activeCaptureText press $_stopCaptureLabel when done'
                              : (_captureMessage ??
                                  'Press $_startCaptureLabel, then get ready...'))
                          : visibleSentence,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: sentence.isEmpty
                            ? const Color(0x33FFFFFF)
                            : Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                      ),
                    ),
                  ),
                  if (spellingMode && _curWord.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0x2600E5CC),
                        border: Border.all(
                          color: const Color(0x8000E5CC),
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _curWord,
                        style: const TextStyle(
                          color: kTeal,
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 7),
          if (suggestions.isNotEmpty) ...[
            SizedBox(
              height: 46,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: suggestions
                    .map(
                      (word) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: GestureDetector(
                          onTap: () => setState(() => _commitWord(word)),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0x1A00E5CC),
                              border: Border.all(
                                color: const Color(0x6600E5CC),
                                width: 0.5,
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              word,
                              style: const TextStyle(
                                color: kTeal,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 7),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (!_isLockedWordPractice)
                _ActBtn(label: 'Delete', onTap: _deleteLast),
              if (spellingMode) _ActBtn(label: 'Space', onTap: _addSpace),
              if (!_detectionArmed && _startCountdown == 0)
                _ActBtn(
                  label: _startCaptureLabel,
                  accent: true,
                  icon: Icons.play_arrow_rounded,
                  onTap: _startSigningCountdown,
                ),
              if (_detectionArmed)
                _ActBtn(
                  label: _stopCaptureLabel,
                  accent: true,
                  icon: Icons.stop_rounded,
                  onTap: _finishSigningCapture,
                ),
              if (!_isLockedWordPractice)
                _ActBtn(
                  label: 'Clear',
                  icon: Icons.refresh_rounded,
                  onTap: _clearAll,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStartOverlay() {
    final isCountingDown = _startCountdown > 0;
    return Positioned.fill(
      child: Stack(
        children: [
          Container(
            color: const Color(0x78000000),
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 112,
                      height: 112,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xD0000000),
                        shape: BoxShape.circle,
                        border: Border.all(color: kTeal, width: 2),
                      ),
                      child: Text(
                        isCountingDown ? '$_startCountdown' : 'Ready',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: kTeal,
                          fontSize: isCountingDown ? 54 : 24,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      isCountingDown
                          ? 'Position your hand in the frame'
                          : 'Press capture before signing',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isCountingDown
                          ? 'Capture starts after the countdown.'
                          : widget.title == 'Basic Word Practice' ||
                                  widget.title == 'SIGN TO TEXT'
                              ? 'Make sure your face and hands are both visible. '
                                  'The app will wait $_prepareSeconds seconds so you can position properly.'
                              : 'The app will wait $_prepareSeconds seconds so you can position properly.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xB3FFFFFF),
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (!isCountingDown)
                      Center(
                        child: GestureDetector(
                          onTap: _startSigningCountdown,
                          child: Container(
                            width: 148,
                            height: 52,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: kTeal,
                              borderRadius: BorderRadius.circular(26),
                              boxShadow: [
                                BoxShadow(
                                  color: kTeal.withValues(alpha: 0.36),
                                  blurRadius: 18,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: const Text(
                              'Capture',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 14,
            child: _OverlayBackButton(
              onTap: () => Navigator.of(context).maybePop(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: kBg,
      child: Stack(
        children: [
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 14,
            child: GestureDetector(
              onTap: () => Navigator.of(context).maybePop(),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF39D8E8), Color(0xFF1387C9)],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.8),
                    width: 1.4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: kTeal.withValues(alpha: 0.5),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.arrow_back_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 84,
                  height: 84,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF39D8E8), Color(0xFF1387C9)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: kTeal.withValues(alpha: 0.45),
                        blurRadius: 22,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: const SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3.4,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    _loadText,
                    style: const TextStyle(
                      color: Color(0xCCFFFFFF),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OverlayBackButton extends StatelessWidget {
  final VoidCallback onTap;

  const _OverlayBackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF39D8E8), Color(0xFF1387C9)],
          ),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.8),
            width: 1.4,
          ),
          boxShadow: [
            BoxShadow(
              color: _SignDetectorScreenState.kTeal.withValues(alpha: 0.5),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(
          Icons.arrow_back_rounded,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }
}

class _TopBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _TopBtn({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: active
              ? const LinearGradient(
                  colors: [Color(0xFF39D8E8), Color(0xFF1387C9)],
                )
              : null,
          color: active ? null : const Color(0x99000000),
          border: Border.all(
            color: active
                ? Colors.white.withValues(alpha: 0.75)
                : const Color(0x33FFFFFF),
            width: active ? 1.2 : 0.5,
          ),
          borderRadius: BorderRadius.circular(999),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: const Color(0xFF00E5CC).withValues(alpha: 0.45),
                    blurRadius: 8,
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : const Color(0xB3FFFFFF),
            fontSize: 12,
            fontWeight: active ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _ModeBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ModeBtn({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: active
              ? const LinearGradient(
                  colors: [Color(0xFF39D8E8), Color(0xFF1387C9)],
                )
              : null,
          color: active ? null : const Color(0x14FFFFFF),
          border: Border.all(
            color: active
                ? Colors.white.withValues(alpha: 0.8)
                : const Color(0x1FFFFFFF),
            width: active ? 1.4 : 0.5,
          ),
          borderRadius: BorderRadius.circular(999),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: const Color(0xFF00E5CC).withValues(alpha: 0.5),
                    blurRadius: 10,
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: active ? Colors.white : const Color(0x77FFFFFF),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _ActBtn extends StatelessWidget {
  final String label;
  final bool accent;
  final VoidCallback onTap;
  final IconData? icon;

  const _ActBtn({
    required this.label,
    this.accent = false,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          gradient: accent
              ? const LinearGradient(
                  colors: [Color(0xFF39D8E8), Color(0xFF1387C9)],
                )
              : null,
          color: accent ? null : const Color(0x0FFFFFFF),
          border: Border.all(
            color: accent
                ? Colors.white.withValues(alpha: 0.8)
                : const Color(0x1FFFFFFF),
            width: accent ? 1.4 : 0.5,
          ),
          borderRadius: BorderRadius.circular(999),
          boxShadow: accent
              ? [
                  BoxShadow(
                    color: const Color(0xFF00E5CC).withValues(alpha: 0.5),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: accent ? Colors.white : const Color(0x8CFFFFFF),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: accent ? Colors.white : const Color(0x8CFFFFFF),
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniBar extends StatelessWidget {
  final double value;
  final Color color;

  const _MiniBar({required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          height: 3,
          width: constraints.maxWidth,
          decoration: BoxDecoration(
            color: const Color(0x1AFFFFFF),
            borderRadius: BorderRadius.circular(2),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: value.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        );
      },
    );
  }
}
