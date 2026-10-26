import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:hand_landmarker/hand_landmarker.dart' as mp_hand;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../classifiers/sign_classifier.dart';
import '../classifiers/tflite_sign_classifier.dart';
import '../painters/landmark_painter.dart';
import '../services/background_music_service.dart';
import '../ui/background_music_region.dart';

class CalculatorGamePage extends StatefulWidget {
  const CalculatorGamePage({super.key});

  @override
  State<CalculatorGamePage> createState() => _CalculatorGamePageState();
}

class _CalculatorGamePageState extends State<CalculatorGamePage>
    with WidgetsBindingObserver {
  static const _assetRoot = 'assets/calcuavatars';

  CameraController? _cameraController;
  late final mp_hand.HandLandmarkerPlugin _handLandmarker;
  final SignClassifier _classifier = SignClassifier();
  final TfliteSignClassifier _tfliteClassifier = TfliteSignClassifier(
    minimumConfidence: 0.72,
  );
  bool _cameraStarting = false;
  bool _capturing = false;
  bool _processing = false;
  bool _streaming = false;
  bool _modelsReady = false;
  Timer? _roundTimer;
  late final ConfettiController _confettiController;
  int _secondsLeft = 15;
  int _lives = 3;
  int _roundAnswer = 0;
  String _roundEquation = '';
  String _cameraAnswer = '';
  bool _gameOver = false;
  bool _keypadOpen = false;
  int _score = 0;
  int _highScore = 0;
  List<int> _recentScores = [];
  bool _scoreSaved = false;
  bool _newHighScore = false;
  int _frameCounter = 0;
  DateTime _lastInferenceAt = DateTime.fromMillisecondsSinceEpoch(0);

  String _display = '0';
  String _expression = '';
  String? _pendingOperator;
  double? _storedValue;
  bool _replaceDisplay = false;
  List<HandLandmark>? _handLandmarks;
  SignResult? _currentHit;
  String? _stableInput;
  String? _lastRawInput;
  int _stableFrames = 0;

  static const int _processEveryNFrames = 5;
  static const int _stableFramesNeeded = 5;
  static const Duration _minInferenceGap = Duration(milliseconds: 180);
  static const Map<String, String> _commandSigns = {
    'A': 'AC',
    'C': 'AC',
    'D': 'DEL',
    'P': '+',
    'M': '-',
    'X': 'x',
    'Q': '÷',
    'E': '=',
  };

  bool get _cameraReady =>
      _cameraController != null && _cameraController!.value.isInitialized;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 3));
    WidgetsBinding.instance.addObserver(this);
    _handLandmarker = mp_hand.HandLandmarkerPlugin.create(
      numHands: 1,
      minHandDetectionConfidence: 0.55,
      delegate: mp_hand.HandLandmarkerDelegate.cpu,
    );
    _newRound();
    unawaited(_loadScoreData());
    _roundTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _gameOver) return;
      if (_secondsLeft <= 1) {
        _loseLife('Time is up!');
      } else {
        setState(() => _secondsLeft--);
      }
    });
    unawaited(_loadModels());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_stopImageStream());
    _cameraController?.dispose();
    _handLandmarker.dispose();
    _tfliteClassifier.close();
    _roundTimer?.cancel();
    _confettiController.dispose();
    super.dispose();
  }

  void _newRound() {
    final random = math.Random();
    const operators = ['+', '-', 'x', '÷'];
    int left;
    int right;
    String operator;
    int answer;
    do {
      operator = operators[random.nextInt(operators.length)];
      switch (operator) {
        case '+':
          left = random.nextInt(21);
          right = random.nextInt(21 - left);
          answer = left + right;
        case '-':
          left = random.nextInt(21);
          right = random.nextInt(left + 1);
          answer = left - right;
        case 'x':
          left = random.nextInt(21);
          right = random.nextInt(21);
          answer = left * right;
        default:
          right = random.nextInt(10) + 1;
          answer = random.nextInt(21);
          left = right * answer;
      }
    } while (answer > 20);
    _roundAnswer = answer;
    _roundEquation = '$left $operator $right =';
    _secondsLeft = 15;
    _cameraAnswer = '';
    // Every question starts fresh: close the keypad and clear what was typed,
    // so the player can choose again between the keypad and the camera.
    _keypadOpen = false;
    _clearCalculator();
  }

  Future<void> _loadScoreData() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _highScore = preferences.getInt('calculator_high_score') ?? 0;
      _recentScores = preferences
              .getStringList('calculator_recent_scores')
              ?.map(int.tryParse)
              .whereType<int>()
              .take(5)
              .toList() ??
          [];
    });
  }

  Future<void> _saveSessionScore() async {
    if (_scoreSaved) return;
    _scoreSaved = true;
    final preferences = await SharedPreferences.getInstance();
    final previousHighScore = preferences.getInt('calculator_high_score') ?? 0;
    final highScore = math.max(_highScore, _score);
    final recentScores = [_score, ..._recentScores].take(5).toList();
    await preferences.setInt('calculator_high_score', highScore);
    await preferences.setStringList(
      'calculator_recent_scores',
      recentScores.map((score) => score.toString()).toList(),
    );
    if (!mounted) return;
    setState(() {
      _highScore = highScore;
      _recentScores = recentScores;
      _newHighScore = _score > 0 && _score > previousHighScore;
    });
    if (_newHighScore) _confettiController.play();
  }

  void _loseLife(String message) {
    if (_gameOver) return;
    setState(() {
      _lives--;
      _keypadOpen = false;
      _clearCalculator();
      if (_lives == 0) {
        _gameOver = true;
        _roundTimer?.cancel();
        _roundTimer = null;
        unawaited(_saveSessionScore());
      } else {
        _newRound();
      }
    });
    _showMessage(_gameOver ? 'Game over!' : message);
  }

  void _restartGame() {
    setState(() {
      _lives = 3;
      _gameOver = false;
      _score = 0;
      _scoreSaved = false;
      _newHighScore = false;
      _newRound();
    });
    _roundTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _gameOver) return;
      if (_secondsLeft <= 1) {
        _loseLife('Time is up!');
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  // Checks the sign captured with "Capture Sign" against the equation.
  // Nothing is checked until the player presses Submit.
  void _submitCameraAnswer() {
    if (_gameOver) return;
    final number = int.tryParse(_cameraAnswer);
    if (number == null) {
      _showMessage('Capture your sign first.');
      return;
    }
    if (number == _roundAnswer) {
      setState(() {
        _score++;
        _newRound();
      });
      _showMessage('Correct!');
    } else {
      _loseLife('Try the next one!');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_cameraReady) return;
    if (state == AppLifecycleState.inactive) {
      _stopCamera();
    }
  }

  Future<void> _loadModels() async {
    await _tfliteClassifier.load();
    if (!mounted) return;
    setState(() => _modelsReady = true);
  }

  Future<void> _startCamera() async {
    if (_cameraStarting) return;
    setState(() {
      _cameraStarting = true;
    });

    final permission = await Permission.camera.request();
    if (!permission.isGranted) {
      if (!mounted) return;
      setState(() => _cameraStarting = false);
      _showMessage('Camera permission is needed to detect signs.');
      return;
    }

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) _showMessage('No camera found on this device.');
        return;
      }

      final camera = cameras.firstWhere(
        (item) => item.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        camera,
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await controller.initialize();
      await _stopImageStream();
      await _cameraController?.dispose();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _cameraController = controller;
        _handLandmarks = null;
        _currentHit = null;
        _stableInput = null;
      });
      await _startImageStream();
    } catch (error) {
      if (mounted) _showMessage('Camera error: $error');
    } finally {
      if (mounted) setState(() => _cameraStarting = false);
    }
  }

  Future<void> _stopCamera() async {
    final controller = _cameraController;
    await _stopImageStream();
    _cameraController = null;
    _handLandmarks = null;
    _currentHit = null;
    _stableInput = null;
    if (mounted) setState(() {});
    await controller?.dispose();
  }

  Future<void> _captureFrame() async {
    if (!_cameraReady || _capturing) {
      _showMessage('Start the camera first.');
      return;
    }
    final input = _stableInput;
    if (input == null) {
      _showMessage('Hold a clear calculator sign first.');
      return;
    }
    setState(() => _capturing = true);
    try {
      if (_isCalculatorNumber(input)) {
        setState(() => _cameraAnswer = input);
        _showMessage('Captured $input. Press Submit to check it.');
      } else {
        _showMessage('Sign a number from 0 to 20.');
      }
    } catch (error) {
      if (mounted) _showMessage('Sign input failed: $error');
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  void _showManualKeypad() {
    setState(() {
      _keypadOpen = true;
      // Drop stale camera detections so they can't be submitted later.
      _handLandmarks = null;
      _currentHit = null;
      _stableInput = null;
      _lastRawInput = null;
      _stableFrames = 0;
    });
  }

  // Submits the answer from the manual keypad against the current equation
  // (the keypad's counterpart of the camera's Capture Sign button).
  void _submitManualAnswer() {
    if (_gameOver) return;
    if (_pendingOperator != null && !_replaceDisplay) {
      setState(_resolveOperation);
    }
    final value = double.tryParse(_display);
    if (value == null) {
      _showMessage('Type your answer first.');
      return;
    }
    if (value == _roundAnswer.toDouble()) {
      setState(() {
        _score++;
        _newRound();
      });
      _showMessage('Correct!');
    } else {
      _loseLife('Try the next one!');
    }
  }

  void _closeManualKeypad() {
    setState(() => _keypadOpen = false);
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
    } catch (_) {
      // The camera plugin can throw if the stream is already stopping.
    } finally {
      _streaming = false;
      _processing = false;
    }
  }

  void _onCameraFrame(CameraImage image) {
    if (_processing || !_cameraReady || _keypadOpen) return;
    _frameCounter++;
    if (_frameCounter % _processEveryNFrames != 0) return;

    final now = DateTime.now();
    if (now.difference(_lastInferenceAt) < _minInferenceGap) return;
    _lastInferenceAt = now;
    unawaited(_processFrame(image));
  }

  Future<void> _processFrame(CameraImage image) async {
    _processing = true;
    try {
      final controller = _cameraController;
      if (controller == null || image.planes.length < 3) return;

      final detectedHands = _handLandmarker.detect(
        image,
        controller.description.sensorOrientation,
      );
      final landmarks = detectedHands.isEmpty
          ? null
          : _mapHandLandmarks(detectedHands.first.landmarks);
      final hit =
          landmarks == null ? null : await _classifyCalculatorSign(landmarks);
      final input = hit == null ? null : _calculatorInputFor(hit);

      if (!mounted) return;
      setState(() {
        _handLandmarks = landmarks;
        _currentHit = hit;
        _updateStableInput(input);
      });
    } catch (error) {
      debugPrint('Calculator hand detection error: $error');
    } finally {
      _processing = false;
    }
  }

  List<HandLandmark> _mapHandLandmarks(List<mp_hand.Landmark> landmarks) {
    return landmarks
        .map((landmark) => HandLandmark(landmark.x, landmark.y, landmark.z))
        .toList(growable: false);
  }

  Future<SignResult?> _classifyCalculatorSign(
    List<HandLandmark> landmarks,
  ) async {
    final tfliteNumberHit = await _tfliteClassifier.classifyNumber(landmarks);
    if (tfliteNumberHit != null && _calculatorInputFor(tfliteNumberHit) != null) {
      return tfliteNumberHit;
    }

    final ruleNumberHit = _classifier.classifyNumber(landmarks);
    if (ruleNumberHit != null && _calculatorInputFor(ruleNumberHit) != null) {
      return ruleNumberHit;
    }

    final tfliteAlphabetHit =
        await _tfliteClassifier.classifyAlphabet(landmarks);
    if (tfliteAlphabetHit != null && _calculatorInputFor(tfliteAlphabetHit) != null) {
      return tfliteAlphabetHit;
    }

    final ruleAlphabetHit = _classifier.classifyAlphabet(landmarks);
    if (ruleAlphabetHit != null && _calculatorInputFor(ruleAlphabetHit) != null) {
      return ruleAlphabetHit;
    }

    return null;
  }

  String? _calculatorInputFor(SignResult hit) {
    final label = hit.label.toUpperCase();
    if (_isCalculatorNumber(label)) return label;
    return _commandSigns[label];
  }

  bool _isCalculatorNumber(String value) {
    final number = int.tryParse(value);
    return number != null && number >= 0 && number <= 20;
  }

  void _updateStableInput(String? input) {
    if (input == null) {
      _lastRawInput = null;
      _stableFrames = 0;
      _stableInput = null;
      return;
    }

    if (input == _lastRawInput) {
      _stableFrames++;
    } else {
      _lastRawInput = input;
      _stableFrames = 1;
    }

    _stableInput = _stableFrames >= _stableFramesNeeded ? input : null;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  void _onCalculatorTap(String value) {
    if (_gameOver) return;
    if (value == '=') {
      setState(() {
        if (_pendingOperator != null) _resolveOperation();
      });
      final answer = double.tryParse(_display);
      if (answer == null) {
        _showMessage('Enter your answer first.');
      } else if (answer == _roundAnswer.toDouble()) {
        setState(() {
          _score++;
          _newRound();
        });
        _showMessage('Correct!');
      } else {
        _loseLife('Try the next one!');
      }
      return;
    }

    setState(() {
      if (RegExp(r'^\d$').hasMatch(value)) {
        _inputDigit(value);
      } else if (value == '.') {
        _inputDecimal();
      } else if (value == 'AC') {
        _clearCalculator();
      } else if (value == 'DEL') {
        _deleteLast();
      } else {
        _chooseOperator(value);
      }
    });
  }

  // Keeps the equation preview ("12 + 5") in sync with whatever the person
  // is currently typing or signing for the right-hand operand.
  void _syncExpressionWithDisplay() {
    if (_pendingOperator != null && _storedValue != null) {
      _expression =
          '${_formatNumber(_storedValue!)} $_pendingOperator $_display';
    }
  }

  void _inputDigit(String digit) {
    if (_replaceDisplay || _display == '0') {
      _display = digit;
      _replaceDisplay = false;
    } else if (_display.length < 10) {
      _display += digit;
    }
    _syncExpressionWithDisplay();
  }

  void _inputDecimal() {
    if (_replaceDisplay) {
      _display = '0.';
      _replaceDisplay = false;
    } else if (!_display.contains('.')) {
      _display += '.';
    }
    _syncExpressionWithDisplay();
  }

  void _clearCalculator() {
    _display = '0';
    _expression = '';
    _storedValue = null;
    _pendingOperator = null;
    _replaceDisplay = false;
  }

  void _deleteLast() {
    if (_replaceDisplay || _display.length <= 1) {
      _display = '0';
      _replaceDisplay = false;
    } else {
      _display = _display.substring(0, _display.length - 1);
    }
    _syncExpressionWithDisplay();
  }

  void _chooseOperator(String operator) {
    if (_pendingOperator != null && !_replaceDisplay) {
      _resolveOperation();
    }
    _storedValue = _currentValue();
    _pendingOperator = operator;
    _replaceDisplay = true;
    _expression = '${_formatNumber(_storedValue!)} $operator';
  }

  void _resolveOperation() {
    final operator = _pendingOperator;
    final left = _storedValue;
    if (operator == null || left == null) return;

    final right = _currentValue();
    final result = switch (operator) {
      '+' => left + right,
      '-' => left - right,
      'x' => left * right,
      '÷' => right == 0 ? double.nan : left / right,
      _ => right,
    };

    _expression = '${_formatNumber(left)} $operator ${_formatNumber(right)} =';
    _display = result.isNaN ? 'Error' : _formatNumber(result);
    _storedValue = null;
    _pendingOperator = null;
    _replaceDisplay = true;
  }

  double _currentValue() => double.tryParse(_display) ?? 0;

  String _formatNumber(double value) {
    if (value.isInfinite || value.isNaN) return 'Error';
    if (value % 1 == 0) return value.toInt().toString();
    return value
        .toStringAsFixed(6)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: BackgroundMusicRegion(
        track: BackgroundMusicTrack.calculator,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final canvasWidth =
                constraints.maxWidth.clamp(0.0, 430.0).toDouble();
            final canvasHeight = constraints.maxHeight;
            return Center(
              child: SizedBox(
                width: canvasWidth,
                height: canvasHeight,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: Image.asset(
                        '$_assetRoot/cal-bg.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.topCenter,
                          child: SizedBox(
                            width: canvasWidth - 20,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildTopBar(context),
                                const SizedBox(height: 8),
                                _buildEquationCard(),
                                const SizedBox(height: 10),
                                // Camera box disappears the moment the keypad
                                // opens and fades back in after it is closed.
                                AnimatedOpacity(
                                  duration: _keypadOpen
                                      ? Duration.zero
                                      : const Duration(milliseconds: 200),
                                  opacity: _keypadOpen ? 0 : 1,
                                  child: _buildGameStage(),
                                ),
                                const SizedBox(height: 12),
                                _buildActionButtons(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                      left: 0,
                      right: 0,
                      bottom: _keypadOpen ? 0 : -(canvasHeight * 0.64),
                      height: canvasHeight * 0.64,
                      child: IgnorePointer(
                        ignoring: !_keypadOpen,
                        child: Material(
                          color: const Color(0xEE071B38),
                          child: SafeArea(
                            top: false,
                            child: Column(
                              children: [
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: IconButton(
                                    tooltip: 'Close keypad',
                                    icon: const Icon(Icons.close_rounded),
                                    color: Colors.white,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 40,
                                      minHeight: 36,
                                    ),
                                    onPressed: _closeManualKeypad,
                                  ),
                                ),
                                Expanded(child: _buildCalculator()),
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(24, 6, 24, 8),
                                  child: _GameActionButton(
                                    icon: Icons.check_circle_rounded,
                                    label: 'Submit Answer',
                                    color: const Color(0xFF1FA64A),
                                    onTap: _submitManualAnswer,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (_gameOver)
                      Positioned.fill(
                        child: Container(
                          color: const Color(0xCC000000),
                          alignment: Alignment.center,
                          child: _buildGameOverCard(),
                        ),
                      ),
                    if (!_keypadOpen && !_gameOver) ...[
                      const _DecorativeAsset(
                        asset: 'peace.png',
                        left: 26,
                        top: 174,
                        width: 48,
                        rotation: -0.18,
                      ),
                      const _DecorativeAsset(
                        asset: 'wssun.png',
                        right: 20,
                        top: 78,
                        width: 76,
                      ),
                      const _DecorativeAsset(
                        asset: 'cloud.png',
                        left: 77,
                        top: 78,
                        width: 48,
                      ),
                      const _DecorativeAsset(
                        asset: 'clouds.png',
                        right: 39,
                        top: 146,
                        width: 48,
                      ),
                      const _DecorativeAsset(
                        asset: 'bulb.png',
                        right: 4,
                        top: 386,
                        width: 38,
                        rotation: 0.16,
                      ),
                      const _DecorativeAsset(
                        asset: 'rainbow.png',
                        left: -6,
                        bottom: 248,
                        width: 83,
                      ),
                      const _DecorativeAsset(
                        asset: 'avatar.png',
                        right: 0,
                        bottom: 0,
                        width: 103,
                      ),
                      const _DecorativeAsset(
                        asset: 'flowers.png',
                        left: 4,
                        bottom: 0,
                        width: 72,
                      ),
                    ],
                    if (_gameOver && _newHighScore)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: ConfettiWidget(
                              confettiController: _confettiController,
                              blastDirectionality:
                                  BlastDirectionality.explosive,
                              emissionFrequency: 0.08,
                              numberOfParticles: 18,
                              maxBlastForce: 18,
                              minBlastForce: 8,
                              gravity: 0.1,
                              shouldLoop: false,
                              colors: const [
                                Color(0xFFFFA000),
                                Color(0xFF1268EA),
                                Color(0xFFFFD43B),
                                Color(0xFF35C84A),
                                Colors.white,
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            _CircleIconButton(
              color: const Color(0xFFF3382E),
              icon: Icons.arrow_back_rounded,
              onTap: () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(width: 10),
            _StatusPill(
              icon: Icons.timer_rounded,
              label: '$_secondsLeft',
              color: _secondsLeft <= 5
                  ? const Color(0xFFF3382E)
                  : const Color(0xFF1268EA),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: 'Correct answers: $_score',
              child: _StatusPill(
                icon: Icons.check_circle_rounded,
                label: '$_score',
                color: const Color(0xFFFF7900),
              ),
            ),
          ],
        ),
        Row(
          children: List.generate(
            3,
            (index) => Padding(
              padding: const EdgeInsets.only(left: 3),
              child: Icon(
                Icons.favorite_rounded,
                size: 30,
                color: index < _lives
                    ? const Color(0xFFF3382E)
                    : Colors.white.withValues(alpha: 0.25),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGameOverCard() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 360),
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFA000),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFFD54F), width: 3),
        boxShadow: const [
          BoxShadow(color: Color(0x9900528C), offset: Offset(0, 6)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('GAME OVER!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w900,
              )),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1268EA),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Column(children: [
              const Text('YOUR SCORE',
                  style: TextStyle(
                    color: Color(0xFFFFD43B),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  )),
              Text('$_score',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                  )),
            ]),
          ),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text('HIGH SCORE  ',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                )),
            Text('$_highScore',
                style: const TextStyle(
                  color: Color(0xFF1268EA),
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                )),
          ]),
          if (_newHighScore) ...[
            const SizedBox(height: 7),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF35C84A),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Text('NEW HIGH SCORE!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  )),
            ),
          ],
          const SizedBox(height: 16),
          _GameActionButton(
            icon: Icons.refresh_rounded,
            label: 'Play Again',
            color: const Color(0xFF1268EA),
            onTap: _restartGame,
          ),
          const SizedBox(height: 10),
          _GameActionButton(
            icon: Icons.exit_to_app_rounded,
            label: 'Exit',
            color: const Color.fromARGB(19, 252, 248, 248),
            onTap: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    );
  }

  Widget _buildEquationCard() {
    return Container(
      width: 320,
      height: 116,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF1268EA),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF72D9FF), width: 3),
        boxShadow: const [
          BoxShadow(color: Color(0x8800528C), offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('SOLVE THIS!',
              style: TextStyle(
                color: Color(0xFFFFD43B),
                fontSize: 13,
                fontWeight: FontWeight.w900,
              )),
          const SizedBox(height: 5),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_roundEquation,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                  )),
              const SizedBox(width: 8),
              Container(
                width: 58,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _cameraAnswer.isEmpty
                      ? const Color(0xFFFFB20D)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: const Color(0xFFFFD43B), width: 2),
                ),
                child: Text(_cameraAnswer,
                    style: const TextStyle(
                      color: Color(0xFF1268EA),
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    )),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGameStage() {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Container(
          width: 320,
          height: 320,
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: const Color(0xFFFFA000),
            borderRadius: BorderRadius.circular(21),
            border: Border.all(color: const Color(0xFFFFD54F), width: 3),
            boxShadow: const [
              BoxShadow(
                color: Color(0x8800528C),
                blurRadius: 0,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: CustomPaint(
            painter: const _DashedFramePainter(),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Container(
                color: const Color(0xFF666666),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildCameraPreview(),
                    if (_cameraReady && _handLandmarks != null)
                      CustomPaint(
                        painter: LandmarkPainter(
                          handLandmarks: _handLandmarks,
                          previewSize:
                              _cameraController!.value.previewSize ?? Size.zero,
                          lensDirection:
                              _cameraController!.description.lensDirection,
                          sensorOrientation:
                              _cameraController!.description.sensorOrientation,
                        ),
                      ),
                    _buildDetectionBadge(),
                  ],
                ),
              ),
            ),
          ),
        ),
        const Positioned(
          left: -48,
          top: 52,
          child: _MotionMarks(color: Color(0xFFFFD43B)),
        ),
        const Positioned(
          right: -44,
          top: 75,
          child: _MotionMarks(color: Color(0xFFFF3EA5), flipped: true),
        ),
      ],
    );
  }

  Widget _buildDetectionBadge() {
    final text = _stableInput != null
        ? 'Ready: $_stableInput'
        : _currentHit != null
            ? 'Hold ${_calculatorInputFor(_currentHit!)}'
            : _cameraReady
                ? (_modelsReady ? 'Show sign' : 'Loading model')
                : 'Start camera';

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xCC000000),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white, width: 1),
        ),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (_cameraReady) {
      return SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _cameraController!.value.previewSize?.height ?? 1,
            height: _cameraController!.value.previewSize?.width ?? 1,
            child: CameraPreview(_cameraController!),
          ),
        ),
      );
    }

    return Center(
      child: AnimatedOpacity(
        opacity: _cameraStarting ? 1 : 0,
        duration: const Duration(milliseconds: 180),
        child: const SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 3,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                  child: _GameActionButton(
                icon: Icons.calculate_rounded,
                label: 'Manual Keypad',
                color: const Color(0xFFFF7900),
                onTap: _showManualKeypad,
              )),
              const SizedBox(width: 8),
              Expanded(
                  child: _GameActionButton(
                icon: Icons.camera_alt_rounded,
                label: _cameraReady ? 'Capture Sign' : 'Camera',
                color: const Color(0xFF1268EA),
                onTap: _cameraReady ? _captureFrame : _startCamera,
              )),
            ],
          ),
          if (_cameraReady) ...[
            const SizedBox(height: 8),
            _GameActionButton(
              icon: Icons.check_circle_rounded,
              label: 'Submit Answer',
              color: const Color(0xFF1FA64A),
              onTap: _submitCameraAnswer,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCalculator() {
    const rows = [
      ['AC', 'DEL', '÷', 'x'],
      ['7', '8', '9', ''],
      ['4', '5', '6', '-'],
      ['3', '2', '1', '+'],
      ['0', '.', '=', ''],
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final calculatorWidth =
            math.min(constraints.maxWidth - 16, 330.0).clamp(0.0, 330.0);
        final buttonGap = calculatorWidth < 285 ? 8.0 : 10.0;
        final horizontalPadding = calculatorWidth < 285 ? 10.0 : 14.0;
        // Estimate a nominal button size only for the height calculation.
        // Actual widths are handed off to Expanded below so the row can
        // never overflow, even by a fraction of a pixel.
        final nominalButtonWidth =
            (calculatorWidth - horizontalPadding * 2 - buttonGap * 3) / 4;
        final widthBased =
            (nominalButtonWidth * 0.78 - 2.0).clamp(42.0, 54.0).toDouble();
        // Everything except the 5 button rows: border (4), display (~80),
        // gap under display (12), bottom padding (12) and 4 row gaps.
        final heightBased = constraints.maxHeight.isFinite
            ? (constraints.maxHeight - 4 - 80 - 12 - 12 - buttonGap * 4) / 5
            : widthBased;
        final buttonHeight =
            math.min(widthBased, heightBased).clamp(30.0, 54.0).toDouble();

        return Center(
          child: SingleChildScrollView(
          child: Container(
            width: calculatorWidth,
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              0,
              horizontalPadding,
              12,
            ),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF1E1E1E), width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 8,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 4, top: 6, bottom: 4),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Color(0xFF242424), width: 1),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (_expression.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            _expression,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      SizedBox(
                        height: 44,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            _display,
                            maxLines: 1,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 40,
                              height: 1,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                for (final row in rows) ...[
                  Row(
                    children: [
                      for (final value in row) ...[
                        Expanded(
                          child: value.isEmpty
                              ? const SizedBox.shrink()
                              : _CalcButton(
                                  label: value,
                                  height: buttonHeight,
                                  onTap: () => _onCalculatorTap(value),
                                ),
                        ),
                        if (value != row.last) SizedBox(width: buttonGap),
                      ],
                    ],
                  ),
                  if (row != rows.last) SizedBox(height: buttonGap),
                ],
              ],
            ),
          ),
          ),
        );
      },
    );
  }
}

class _DecorativeAsset extends StatelessWidget {
  final String asset;
  final double? left;
  final double? right;
  final double? top;
  final double? bottom;
  final double width;
  final double rotation;

  const _DecorativeAsset({
    required this.asset,
    this.left,
    this.right,
    this.top,
    this.bottom,
    required this.width,
    this.rotation = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      right: right,
      top: top,
      bottom: bottom,
      child: IgnorePointer(
        child: Transform.rotate(
          angle: rotation,
          child: Image.asset(
            'assets/calcuavatars/$asset',
            width: width,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _CircleIconButton({
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      shape: const CircleBorder(),
      elevation: 4,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Icon(icon, color: Colors.white, size: 31),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatusPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              )),
        ],
      ),
    );
  }
}

class _GameActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _GameActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(14),
      elevation: 4,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          height: 39,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white, width: 2),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 4),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CalcButton extends StatelessWidget {
  final String label;
  final double height;
  final VoidCallback onTap;

  const _CalcButton({
    required this.label,
    required this.height,
    required this.onTap,
  });

  bool get _filled =>
      const {'AC', 'DEL', '÷', 'x', '-', '+', '='}.contains(label);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _filled ? const Color(0xFFFFB20D) : Colors.black,
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        borderRadius: BorderRadius.circular(7),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          height: height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: const Color(0xFFFFB20D), width: 2),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(
                color: _filled ? Colors.black : Colors.white,
                fontSize: label.length > 1 ? 18 : 28,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MotionMarks extends StatelessWidget {
  final Color color;
  final bool flipped;

  const _MotionMarks({
    required this.color,
    this.flipped = false,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scaleX: flipped ? -1 : 1,
      child: CustomPaint(
        size: const Size(31, 40),
        painter: _MotionMarksPainter(color),
      ),
    );
  }
}

class _MotionMarksPainter extends CustomPainter {
  final Color color;

  const _MotionMarksPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * 0.80, size.height * 0.16),
      Offset(size.width * 0.40, size.height * 0.35),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.90, size.height * 0.50),
      Offset(size.width * 0.42, size.height * 0.50),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.80, size.height * 0.84),
      Offset(size.width * 0.40, size.height * 0.65),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DashedFramePainter extends CustomPainter {
  const _DashedFramePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(3),
      const Radius.circular(16),
    );
    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    for (final metric in metrics) {
      var distance = 0.0;
      const dash = 3.0;
      const gap = 3.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + dash),
          paint,
        );
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}