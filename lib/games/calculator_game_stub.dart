import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/background_music_service.dart';
import '../ui/background_music_region.dart';

class CalculatorGamePage extends StatefulWidget {
  const CalculatorGamePage({super.key});

  @override
  State<CalculatorGamePage> createState() => _CalculatorGamePageState();
}

class _CalculatorGamePageState extends State<CalculatorGamePage> {
  static const _assetRoot = 'assets/calcuavatars';

  String _display = '0';
  String _expression = '';
  String? _pendingOperator;
  double? _storedValue;
  bool _replaceDisplay = false;
  Timer? _roundTimer;
  int _secondsLeft = 15;
  int _lives = 3;
  String _roundEquation = '';
  bool _gameOver = false;
  bool _keypadOpen = false;
  int _score = 0;
  int _highScore = 0;
  List<int> _recentScores = [];
  bool _scoreSaved = false;
  bool _newHighScore = false;

  @override
  void initState() {
    super.initState();
    _newRound();
    unawaited(_loadScoreData());
    _roundTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _gameOver) return;
      setState(() {
        if (_secondsLeft <= 1) {
          _lives--;
          _secondsLeft = 15;
          _newRound();
          if (_lives == 0) {
            _gameOver = true;
            _roundTimer?.cancel();
            _roundTimer = null;
            unawaited(_saveSessionScore());
          }
        } else {
          _secondsLeft--;
        }
      });
    });
  }

  @override
  void dispose() {
    _roundTimer?.cancel();
    super.dispose();
  }

  void _newRound() {
    final random = math.Random();
    final operator = ['+', '-', 'x', '÷'][random.nextInt(4)];
    late final int left;
    late final int right;
    switch (operator) {
      case '+':
        left = random.nextInt(11);
        right = random.nextInt(21 - left);
      case '-':
        left = random.nextInt(21);
        right = random.nextInt(left + 1);
      case 'x':
        left = random.nextInt(5);
        right = random.nextInt(5);
      default:
        right = random.nextInt(10) + 1;
        left = right * random.nextInt(11);
    }
    _roundEquation = '$left $operator $right =';
    _secondsLeft = 15;
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
      _newHighScore = _score > previousHighScore;
    });
  }

  void _showManualKeypad() {
    setState(() => _keypadOpen = true);
  }

  void _closeManualKeypad() {
    setState(() => _keypadOpen = false);
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
        setState(() {
          _lives--;
          if (_lives == 0) {
            _gameOver = true;
            _roundTimer?.cancel();
            _roundTimer = null;
            unawaited(_saveSessionScore());
          } else {
            _newRound();
          }
        });
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  void _onCalculatorTap(String value) {
    setState(() {
      if (RegExp(r'^\d$').hasMatch(value)) {
        _inputDigit(value);
      } else if (value == '.') {
        _inputDecimal();
      } else if (value == 'AC') {
        _clearCalculator();
      } else if (value == 'DEL') {
        _deleteLast();
      } else if (value == '=') {
        _resolveOperation();
      } else {
        _chooseOperator(value);
      }
    });
  }

  // Keeps the equation preview ("12 + 5") in sync with whatever the person
  // is currently typing for the right-hand operand.
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
                                _buildWebStage(),
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
                      bottom: _keypadOpen ? 0 : -(canvasHeight / 2),
                      height: canvasHeight / 2,
                      child: IgnorePointer(
                        ignoring: !_keypadOpen,
                        child: Material(
                          color: const Color(0xEE071B38),
                          child: SafeArea(
                            child: Column(
                              children: [
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: IconButton(
                                    tooltip: 'Close keypad',
                                    icon: const Icon(Icons.close_rounded),
                                    color: Colors.white,
                                    onPressed: _closeManualKeypad,
                                  ),
                                ),
                                Expanded(child: _buildCalculator()),
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
                      asset: 'sign.png',
                      right: 19,
                      top: 274,
                      width: 78,
                      rotation: 0.13,
                    ),
                    const _DecorativeAsset(
                      asset: 'bulb.png',
                      right: 4,
                      top: 386,
                      width: 38,
                      rotation: 0.16,
                    ),
                    const _DecorativeAsset(
                      asset: 'avatar.png',
                      right: 6,
                      bottom: 31,
                      width: 103,
                    ),
                    const _DecorativeAsset(
                      asset: 'flowers.png',
                      left: 4,
                      bottom: 0,
                      width: 72,
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
        Row(children: [
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
        ]),
        Row(
            children: List.generate(
                3,
                (index) => Icon(
                      Icons.favorite_rounded,
                      size: 30,
                      color: index < _lives
                          ? const Color(0xFFF3382E)
                          : Colors.white.withValues(alpha: 0.25),
                    ))),
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
          BoxShadow(color: Color(0x9900528C), offset: Offset(0, 6))
        ],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
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
        const SizedBox(height: 12),
        const Align(
            alignment: Alignment.centerLeft,
            child: Text('RECENT SCORES',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ))),
        const SizedBox(height: 6),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var index = 0; index < _recentScores.length; index++)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: index == 0 ? const Color(0xFF1268EA) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: index == 0 ? Colors.white : const Color(0xFF1268EA),
                    width: 2,
                  ),
                ),
                child: Text('${_recentScores[index]}',
                    style: TextStyle(
                      color:
                          index == 0 ? Colors.white : const Color(0xFF1268EA),
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    )),
              ),
          ],
        ),
        const SizedBox(height: 16),
        _GameActionButton(
          icon: Icons.refresh_rounded,
          label: 'Play Again',
          color: const Color(0xFF1268EA),
          onTap: _restartGame,
        ),
      ]),
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
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('SOLVE THIS!',
            style: TextStyle(
              color: Color(0xFFFFD43B),
              fontSize: 13,
              fontWeight: FontWeight.w900,
            )),
        const SizedBox(height: 5),
        Row(mainAxisSize: MainAxisSize.min, children: [
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
              color: const Color(0xFFFFB20D),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: const Color(0xFFFFD43B), width: 2),
            ),
            child: const SizedBox.shrink(),
          ),
        ]),
      ]),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
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
          label: 'Camera',
          color: const Color(0xFF1268EA),
          onTap: () =>
              _showMessage('Camera sign input runs in the Android app.'),
        )),
      ]),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildWebStage() {
    return Container(
      width: 320,
      height: 320,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFA000),
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: const Color(0xFFFFD54F), width: 3),
      ),
      child: const Center(
        child: Text(
          'CAMERA\nSign input is available\nin the Android app.',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
        ),
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
        final buttonHeight =
            (nominalButtonWidth * 0.78 - 2.0).clamp(42.0, 54.0).toDouble();

        return Center(
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
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            )),
      ]),
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
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          height: 58,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(width: 6),
            Flexible(
                child: Text(label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ))),
          ]),
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
