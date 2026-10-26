import 'dart:math';

class SignResult {
  final String label;
  final double confidence;
  final String type; // alphabet | number | word | sequence
  final bool isModelConfidence;

  const SignResult({
    required this.label,
    required this.confidence,
    required this.type,
    this.isModelConfidence = false,
  });
}

class HandLandmark {
  final double x;
  final double y;
  final double z;
  const HandLandmark(this.x, this.y, this.z);
}

class _HandShape {
  final bool index;
  final bool middle;
  final bool ring;
  final bool pinky;
  final bool indexCurled;
  final bool middleCurled;
  final bool ringCurled;
  final bool pinkyCurled;
  final bool thumbOut;
  final bool thumbIn;
  final bool thumbUp;
  final double palm;
  final double spread;

  const _HandShape({
    required this.index,
    required this.middle,
    required this.ring,
    required this.pinky,
    required this.indexCurled,
    required this.middleCurled,
    required this.ringCurled,
    required this.pinkyCurled,
    required this.thumbOut,
    required this.thumbIn,
    required this.thumbUp,
    required this.palm,
    required this.spread,
  });

  int get extendedCount =>
      (index ? 1 : 0) + (middle ? 1 : 0) + (ring ? 1 : 0) + (pinky ? 1 : 0);

  bool get fist => indexCurled && middleCurled && ringCurled && pinkyCurled;
  bool get openFour => index && middle && ring && pinky;
}

class SignClassifier {
  // ─── PERFORMANCE FIX 1: Reduce motion path size ───────────────────────────
  // Was 24 frames — reduced to 12 to lower memory & loop cost each frame.
  // J and Z detection still work with 12+ frames.
  final List<Map<String, double>> _motionPath = [];
  static const int _maxMotionPath = 12;

  // ─── PERFORMANCE FIX 2: Cache palm size per frame ─────────────────────────
  // _palm() was called dozens of times per classify call.
  // Now computed once per frame and cached.
  double? _cachedPalm;
  List<HandLandmark>? _cachedLm;

  double _dist(List<HandLandmark> lm, int a, int b) {
    final dx = lm[a].x - lm[b].x;
    final dy = lm[a].y - lm[b].y;
    return sqrt(dx * dx + dy * dy);
  }

  double _palm(List<HandLandmark> lm) {
    // Return cached value if same landmark set
    if (identical(_cachedLm, lm) && _cachedPalm != null) {
      return _cachedPalm!;
    }
    _cachedLm = lm;
    _cachedPalm = max(max(_dist(lm, 0, 9), _dist(lm, 5, 17)), 0.08);
    return _cachedPalm!;
  }

  bool _rightHandView(List<HandLandmark> lm) => lm[5].x < lm[17].x;

  bool _fingerExtended(List<HandLandmark> lm, int tip, int pip, int mcp) {
    final palm = _palm(lm);
    final awayFromWrist = _dist(lm, 0, tip) > _dist(lm, 0, pip) + 0.13 * palm;
    final awayFromBase =
        _dist(lm, mcp, tip) > _dist(lm, mcp, pip) + 0.08 * palm;
    final upright = lm[tip].y < lm[pip].y - 0.10 * palm;
    return awayFromBase && (awayFromWrist || upright);
  }

  bool _fingerCurled(List<HandLandmark> lm, int tip, int pip, int mcp) {
    final palm = _palm(lm);
    final closeToWrist = _dist(lm, 0, tip) < _dist(lm, 0, pip) + 0.08 * palm;
    final foldedToPalm = _dist(lm, 9, tip) < _dist(lm, 9, pip) + 0.22 * palm;
    final belowJoint = lm[tip].y > lm[pip].y + 0.06 * palm;
    return closeToWrist || foldedToPalm || belowJoint;
  }

  bool _thumbOut(List<HandLandmark> lm) {
    final palm = _palm(lm);
    final right = _rightHandView(lm);
    final lateral = right
        ? lm[4].x < lm[2].x - 0.18 * palm
        : lm[4].x > lm[2].x + 0.18 * palm;
    return lateral || _dist(lm, 4, 9) > _dist(lm, 3, 9) + 0.16 * palm;
  }

  bool _thumbIn(List<HandLandmark> lm) {
    final palm = _palm(lm);
    return _dist(lm, 4, 9) < 0.95 * palm ||
        _dist(lm, 4, 8) < 0.46 * palm ||
        _dist(lm, 4, 12) < 0.46 * palm;
  }

  bool _thumbUp(List<HandLandmark> lm) =>
      lm[4].y < lm[3].y - 0.12 * _palm(lm) && _dist(lm, 4, 0) > _dist(lm, 3, 0);

  bool _near(List<HandLandmark> lm, int a, int b, double amount) =>
      _dist(lm, a, b) < amount * _palm(lm);

  bool _far(List<HandLandmark> lm, int a, int b, double amount) =>
      _dist(lm, a, b) > amount * _palm(lm);

  bool _horizontalFinger(List<HandLandmark> lm, int tip, int mcp) =>
      (lm[tip].y - lm[mcp].y).abs() < 0.34 * _palm(lm) &&
      (lm[tip].x - lm[mcp].x).abs() > 0.48 * _palm(lm);

  bool _fingerUpright(List<HandLandmark> lm, int tip, int pip) =>
      lm[tip].y < lm[pip].y - 0.10 * _palm(lm);

  bool _downFinger(List<HandLandmark> lm, int tip, int mcp) =>
      lm[tip].y > lm[mcp].y + 0.22 * _palm(lm);

  _HandShape _shape(List<HandLandmark> lm) {
    final palm = _palm(lm);
    final index = _fingerExtended(lm, 8, 6, 5);
    final middle = _fingerExtended(lm, 12, 10, 9);
    final ring = _fingerExtended(lm, 16, 14, 13);
    final pinky = _fingerExtended(lm, 20, 18, 17);
    return _HandShape(
      index: index,
      middle: middle,
      ring: ring,
      pinky: pinky,
      indexCurled: !index && _fingerCurled(lm, 8, 6, 5),
      middleCurled: !middle && _fingerCurled(lm, 12, 10, 9),
      ringCurled: !ring && _fingerCurled(lm, 16, 14, 13),
      pinkyCurled: !pinky && _fingerCurled(lm, 20, 18, 17),
      thumbOut: _thumbOut(lm),
      thumbIn: _thumbIn(lm),
      thumbUp: _thumbUp(lm),
      palm: palm,
      spread: _dist(lm, 8, 20) / palm,
    );
  }

  // ─── PERFORMANCE FIX 3: Throttle motion tracking ──────────────────────────
  // Was tracking every single frame. Now tracks every other frame only.
  // Motion detection (J, Z, flicking) still works fine with half the data.
  int _motionFrameCount = 0;

  void _trackMotion(List<HandLandmark> lm) {
    _motionFrameCount++;
    if (_motionFrameCount % 2 != 0) return; // skip every other frame

    _motionPath.add({
      'x': lm[8].x,
      'y': lm[8].y,
      'wristX': lm[0].x,
      'wristY': lm[0].y,
    });
    if (_motionPath.length > _maxMotionPath) _motionPath.removeAt(0);
  }

  // ─── PERFORMANCE FIX 4: Cache range values ────────────────────────────────
  // _range() was recomputed multiple times per frame.
  // Now computed once and cached per classify call.
  double? _cachedRangeX;
  double? _cachedRangeY;
  int _rangeCacheFrame = -1;

  double _range(String key) {
    if (_motionPath.isEmpty) return 0;

    if (key == 'x') {
      if (_cachedRangeX != null && _rangeCacheFrame == _motionFrameCount) {
        return _cachedRangeX!;
      }
      final values = _motionPath.map((p) => p['x']!).toList();
      _cachedRangeX = values.reduce(max) - values.reduce(min);
      _rangeCacheFrame = _motionFrameCount;
      return _cachedRangeX!;
    } else {
      if (_cachedRangeY != null && _rangeCacheFrame == _motionFrameCount) {
        return _cachedRangeY!;
      }
      final values = _motionPath.map((p) => p['y']!).toList();
      _cachedRangeY = values.reduce(max) - values.reduce(min);
      _rangeCacheFrame = _motionFrameCount;
      return _cachedRangeY!;
    }
  }

  bool _detectJ() {
    if (_motionPath.length < 8) return false; // was 16, halved for smaller path
    final a = _motionPath[0];
    final b = _motionPath[4];
    final c = _motionPath[7];
    final dippedDown = b['y']! > a['y']! + 0.020;
    final hookedSideways = (c['x']! - b['x']!).abs() > 0.020;
    return dippedDown && hookedSideways;
  }

  bool _detectZ() {
    if (_motionPath.length < 9) return false; // was 18, halved for smaller path
    final a = _motionPath[0];
    final b = _motionPath[3];
    final c = _motionPath[6];
    final d = _motionPath[8];
    final firstStroke = b['x']! - a['x']!;
    final secondStroke = d['x']! - c['x']!;
    return firstStroke.abs() > 0.020 &&
        c['y']! > b['y']! + 0.015 &&
        secondStroke.abs() > 0.020 &&
        firstStroke.sign == secondStroke.sign;
  }

  bool _flicking() => _range('y') > 0.045 || _range('x') > 0.055;

  double _boost(double value) =>
      min(0.97, value + min(_motionPath.length, 10) * 0.002);

  // ─── PERFORMANCE FIX 5: Smoothing buffer size reduced ─────────────────────
  // Was keeping last 5 frames, requiring 3 matches.
  // Reduced to last 4 frames, requiring 2 matches — same stability, less work.
  final List<String> _recentLabels = [];

  String? smoothedResult(String? newLabel) {
    if (newLabel == null) {
      _recentLabels.clear();
      return null;
    }
    _recentLabels.add(newLabel);
    if (_recentLabels.length > 4) _recentLabels.removeAt(0); // was 5

    final counts = <String, int>{};
    for (final l in _recentLabels) {
      counts[l] = (counts[l] ?? 0) + 1;
    }
    final top = counts.entries.reduce((a, b) => a.value > b.value ? a : b);
    return top.value >= 2 ? top.key : null; // was 3
  }

  void reset() {
    _motionPath.clear();
    _recentLabels.clear();
    _cachedPalm = null;
    _cachedLm = null;
    _cachedRangeX = null;
    _cachedRangeY = null;
    _motionFrameCount = 0;
  }

  SignResult? classifyAlphabet(List<HandLandmark> lm) {
    if (lm.length < 21) return null;
    _trackMotion(lm);
    final s = _shape(lm);

    if (s.pinky &&
        s.indexCurled &&
        s.middleCurled &&
        s.ringCurled &&
        _detectJ()) {
      return const SignResult(label: 'J', confidence: 0.92, type: 'alphabet');
    }
    if (s.index && !s.middle && !s.ring && !s.pinky && _detectZ()) {
      return const SignResult(label: 'Z', confidence: 0.90, type: 'alphabet');
    }
    if (s.openFour && s.thumbIn) {
      return const SignResult(label: 'B', confidence: 0.91, type: 'alphabet');
    }
    if (_near(lm, 4, 8, 0.30) && s.middle && s.ring && s.pinky) {
      return const SignResult(label: 'F', confidence: 0.90, type: 'alphabet');
    }
    if (s.index && s.middle && s.ring && !s.pinky) {
      return const SignResult(label: 'W', confidence: 0.88, type: 'alphabet');
    }
    // R: fingers crossed — tightest proximity, check FIRST
    if (s.index && s.middle && !s.ring && !s.pinky && _near(lm, 8, 12, 0.14)) {
      return const SignResult(label: 'R', confidence: 0.82, type: 'alphabet');
    }
    if (s.index &&
        s.middle &&
        !s.ring &&
        !s.pinky &&
        _near(lm, 8, 12, 0.34) &&
        _horizontalFinger(lm, 8, 5) &&
        _horizontalFinger(lm, 12, 9)) {
      return const SignResult(label: 'H', confidence: 0.84, type: 'alphabet');
    }
    // U: fingers together but not crossed
    if (s.index &&
        s.middle &&
        !s.ring &&
        !s.pinky &&
        _near(lm, 8, 12, 0.32) &&
        _fingerUpright(lm, 8, 6) &&
        _fingerUpright(lm, 12, 10)) {
      return const SignResult(label: 'U', confidence: 0.88, type: 'alphabet');
    }
    // V / K / P: fingers spread apart — check LAST
    if (s.index && s.middle && !s.ring && !s.pinky && _far(lm, 8, 12, 0.32)) {
      if (s.thumbOut && _near(lm, 4, 10, 0.42)) {
        return SignResult(
            label: 'K', confidence: _boost(0.84), type: 'alphabet');
      }
      if (_downFinger(lm, 8, 5) || _downFinger(lm, 12, 9)) {
        return SignResult(
            label: 'P', confidence: _boost(0.82), type: 'alphabet');
      }
      return SignResult(label: 'V', confidence: _boost(0.91), type: 'alphabet');
    }
    if (s.index && !s.middle && !s.ring && !s.pinky && s.thumbOut) {
      if (_downFinger(lm, 8, 5)) {
        return SignResult(
            label: 'Q', confidence: _boost(0.82), type: 'alphabet');
      }
      if (_horizontalFinger(lm, 8, 5) && _near(lm, 4, 8, 0.55) && !s.thumbUp) {
        return SignResult(
            label: 'G', confidence: _boost(0.84), type: 'alphabet');
      }
      return SignResult(label: 'L', confidence: _boost(0.88), type: 'alphabet');
    }
    if (s.index && !s.middle && !s.ring && !s.pinky) {
      if (_near(lm, 4, 12, 0.42) || _near(lm, 4, 16, 0.46)) {
        return const SignResult(label: 'D', confidence: 0.86, type: 'alphabet');
      }
      return SignResult(label: 'D', confidence: _boost(0.78), type: 'alphabet');
    }
    if (!s.index && !s.middle && !s.ring && s.pinky && s.thumbOut) {
      return const SignResult(label: 'Y', confidence: 0.91, type: 'alphabet');
    }
    if (!s.index && !s.middle && !s.ring && s.pinky) {
      return const SignResult(label: 'I', confidence: 0.89, type: 'alphabet');
    }
    if (_near(lm, 4, 8, 0.34) && _near(lm, 4, 12, 0.55) && !s.index) {
      return const SignResult(label: 'O', confidence: 0.86, type: 'alphabet');
    }
    if (!s.index && !s.middle && !s.ring && !s.pinky && !s.fist) {
      return SignResult(label: 'C', confidence: _boost(0.82), type: 'alphabet');
    }
    if (!s.index &&
        s.middleCurled &&
        s.ringCurled &&
        s.pinkyCurled &&
        !s.indexCurled) {
      return SignResult(label: 'X', confidence: _boost(0.82), type: 'alphabet');
    }
    if (s.fist) {
      if (_near(lm, 4, 8, 0.28) && lm[4].x > lm[8].x && s.thumbIn) {
        return SignResult(
            label: 'T', confidence: _boost(0.80), type: 'alphabet');
      }
      if (_near(lm, 4, 12, 0.30) &&
          _near(lm, 4, 16, 0.34) &&
          _far(lm, 4, 8, 0.20)) {
        return SignResult(
            label: 'M', confidence: _boost(0.82), type: 'alphabet');
      }
      if (_near(lm, 4, 8, 0.32) &&
          _near(lm, 4, 12, 0.38) &&
          _far(lm, 4, 16, 0.25)) {
        return SignResult(
            label: 'N', confidence: _boost(0.81), type: 'alphabet');
      }
      if (s.thumbOut || s.thumbUp) {
        return const SignResult(label: 'A', confidence: 0.86, type: 'alphabet');
      }
      if (s.thumbIn) {
        return const SignResult(label: 'E', confidence: 0.84, type: 'alphabet');
      }
      return SignResult(label: 'S', confidence: _boost(0.84), type: 'alphabet');
    }
    return null;
  }

  SignResult? classifyNumber(List<HandLandmark> lm) {
    if (lm.length < 21) return null;
    _trackMotion(lm);
    final s = _shape(lm);

    if (_near(lm, 4, 8, 0.34) && !s.index && !s.middle) {
      return const SignResult(label: '0', confidence: 0.86, type: 'number');
    }
    if (s.thumbUp && s.fist) {
      return const SignResult(label: '10', confidence: 0.88, type: 'number');
    }
    if (s.index && !s.middle && !s.ring && !s.pinky && !s.thumbOut) {
      return const SignResult(label: '1', confidence: 0.88, type: 'number');
    }
    if (s.index && s.middle && !s.ring && !s.pinky && !s.thumbOut) {
      return const SignResult(label: '2', confidence: 0.86, type: 'number');
    }
    if (s.index && s.middle && !s.ring && !s.pinky && s.thumbOut) {
      return const SignResult(label: '3', confidence: 0.84, type: 'number');
    }
    if (s.openFour && !s.thumbOut) {
      return const SignResult(label: '4', confidence: 0.86, type: 'number');
    }
    if (s.openFour && s.thumbOut) {
      return const SignResult(label: '5', confidence: 0.88, type: 'number');
    }
    if (s.index && s.middle && s.ring && !s.pinky && _near(lm, 4, 20, 0.38)) {
      return SignResult(
          label: _flicking() ? '16' : '6', confidence: 0.82, type: 'number');
    }
    if (s.index && s.middle && !s.ring && s.pinky && _near(lm, 4, 16, 0.38)) {
      return SignResult(
          label: _flicking() ? '17' : '7', confidence: 0.80, type: 'number');
    }
    if (s.index && !s.middle && s.ring && s.pinky && _near(lm, 4, 12, 0.38)) {
      return SignResult(
          label: _flicking() ? '18' : '8', confidence: 0.80, type: 'number');
    }
    if (!s.index && s.middle && s.ring && s.pinky && _near(lm, 4, 8, 0.36)) {
      return SignResult(
          label: _flicking() ? '19' : '9', confidence: 0.82, type: 'number');
    }
    if (s.index &&
        s.thumbOut &&
        !s.middle &&
        !s.ring &&
        !s.pinky &&
        _horizontalFinger(lm, 8, 5)) {
      return const SignResult(label: '20', confidence: 0.78, type: 'number');
    }
    return null;
  }

  SignResult? classifyMotionAlphabet(List<HandLandmark> lm) {
    if (lm.length < 21) return null;
    _trackMotion(lm);
    final s = _shape(lm);

    if (s.pinky &&
        s.indexCurled &&
        s.middleCurled &&
        s.ringCurled &&
        _detectJ()) {
      return const SignResult(label: 'J', confidence: 0.92, type: 'alphabet');
    }
    if (s.index && !s.middle && !s.ring && !s.pinky && _detectZ()) {
      return const SignResult(label: 'Z', confidence: 0.90, type: 'alphabet');
    }
    return null;
  }

  SignResult? classifyMotionNumber(List<HandLandmark> lm) {
    if (lm.length < 21) return null;
    _trackMotion(lm);
    if (!_flicking()) return null;

    final s = _shape(lm);
    if (s.index && s.middle && s.ring && !s.pinky && _near(lm, 4, 20, 0.38)) {
      return const SignResult(label: '16', confidence: 0.84, type: 'number');
    }
    if (s.index && s.middle && !s.ring && s.pinky && _near(lm, 4, 16, 0.38)) {
      return const SignResult(label: '17', confidence: 0.82, type: 'number');
    }
    if (s.index && !s.middle && s.ring && s.pinky && _near(lm, 4, 12, 0.38)) {
      return const SignResult(label: '18', confidence: 0.82, type: 'number');
    }
    if (!s.index && s.middle && s.ring && s.pinky && _near(lm, 4, 8, 0.36)) {
      return const SignResult(label: '19', confidence: 0.84, type: 'number');
    }
    return null;
  }

  SignResult? classifyMotionWordsFromHands(List<List<HandLandmark>>? hands) {
    if (hands == null || hands.isEmpty) return null;
    final first = hands.first;
    if (first.length < 21) return null;
    _trackMotion(first);

    if (hands.length > 1 && hands[1].length >= 21 && _flicking()) {
      final twoHand = _classifyTwoHandWord(hands[0], hands[1]);
      if (twoHand != null) return twoHand;
    }

    final s = _shape(first);
    final wristY = first[0].y;
    final movingSideways = _range('x') > 0.035;
    final movingVertical = _range('y') > 0.035;
    final moving = movingSideways || movingVertical;
    if (!moving) return null;

    if (s.openFour && !s.thumbOut && wristY < 0.52 && movingSideways) {
      return const SignResult(label: 'hello', confidence: 0.86, type: 'word');
    }
    if (s.openFour && s.thumbOut && wristY < 0.58 && movingVertical) {
      return const SignResult(
        label: 'thank you',
        confidence: 0.84,
        type: 'word',
      );
    }
    if (s.fist && movingVertical) {
      return const SignResult(label: 'yes', confidence: 0.82, type: 'word');
    }
    if (s.index && s.middle && !s.ring && !s.pinky && movingSideways) {
      return const SignResult(label: 'no', confidence: 0.82, type: 'word');
    }
    if (s.openFour && !s.thumbOut && movingSideways && movingVertical) {
      return const SignResult(label: 'please', confidence: 0.80, type: 'word');
    }
    if (s.fist && s.thumbIn && movingSideways && movingVertical) {
      return const SignResult(label: 'sorry', confidence: 0.80, type: 'word');
    }
    if (s.openFour && s.thumbOut && wristY > 0.55 && movingVertical) {
      return const SignResult(label: 'stop', confidence: 0.82, type: 'word');
    }
    return null;
  }

  SignResult? classifyWordsFromHands(List<List<HandLandmark>>? hands) {
    if (hands == null || hands.isEmpty) return null;
    final first = hands.first;
    if (first.length < 21) return null;
    _trackMotion(first);

    if (hands.length > 1 && hands[1].length >= 21) {
      final twoHand = _classifyTwoHandWord(hands[0], hands[1]);
      if (twoHand != null) return twoHand;
    }
    return classifyWords(first);
  }

  SignResult? _classifyTwoHandWord(List<HandLandmark> a, List<HandLandmark> b) {
    final sa = _shape(a);
    final sb = _shape(b);
    final wristGap = (a[0].x - b[0].x).abs();
    final tipGap = _pointGap(a[8], b[8]);

    // HELP: one flat hand lifts the other fist upward
    // Image: fist on flat palm, pushing up
    if (sa.thumbUp && !sb.thumbUp && sb.openFour ||
        sb.thumbUp && !sa.thumbUp && sa.openFour) {
      return const SignResult(label: 'help', confidence: 0.90, type: 'word');
    }

    // MORE: both hands pinched (all fingertips together), tapping each other
    // Image: both hands O-shape/pinched, fingertips meeting
    if (_near(a, 4, 8, 0.32) && _near(b, 4, 8, 0.32) && tipGap < 0.22) {
      return const SignResult(label: 'more', confidence: 0.90, type: 'word');
    }

    // PAIN: two index fingers pointing at each other, moving in/out
    // Image: both index fingers pointing toward each other
    if (sa.index &&
        sb.index &&
        !sa.middle &&
        !sb.middle &&
        !sa.ring &&
        !sb.ring &&
        tipGap < 0.20) {
      return const SignResult(label: 'pain', confidence: 0.86, type: 'word');
    }

    // STOP: one flat hand chopping down onto other flat palm
    // Image: one open hand slicing down onto other open palm
    if (sa.openFour &&
        sb.openFour &&
        (a[0].y - b[0].y).abs() > 0.08 &&
        wristGap < 0.40) {
      return const SignResult(label: 'stop', confidence: 0.86, type: 'word');
    }

    // HOW: both fists knuckle-to-knuckle, rolling forward
    // Image: both fists touching at knuckles
    if (sa.fist && sb.fist && wristGap < 0.28 && tipGap < 0.25) {
      return const SignResult(label: 'how', confidence: 0.84, type: 'word');
    }

    // ALL DONE / DONE: both open hands flip outward (palms out, spread)
    // Image: both open hands, spreading outward
    if (sa.openFour && sb.openFour && wristGap > 0.28 && tipGap > 0.30) {
      return const SignResult(
          label: 'all done', confidence: 0.84, type: 'word');
    }

    // WANT: both open curved hands pulling toward body
    // Image: both hands curved/claw, pulling inward
    if (sa.openFour &&
        sb.openFour &&
        sa.spread > 0.80 &&
        sb.spread > 0.80 &&
        wristGap < 0.44) {
      return const SignResult(label: 'want', confidence: 0.82, type: 'word');
    }

    // OPEN: both flat hands moving apart (palms facing each other then opening)
    if (sa.openFour && sb.openFour && wristGap > 0.46 && tipGap > 0.38) {
      return const SignResult(label: 'open', confidence: 0.82, type: 'word');
    }

    // PLAY: both Y-hands (pinky+thumb) shaking
    // Image: both hands pinky+thumb extended, shaking
    if (!sa.index &&
        !sa.middle &&
        !sa.ring &&
        sa.pinky &&
        sa.thumbOut &&
        !sb.index &&
        !sb.middle &&
        !sb.ring &&
        sb.pinky &&
        sb.thumbOut) {
      return const SignResult(label: 'play', confidence: 0.86, type: 'word');
    }

    // HURT: two index fingers circling toward each other
    if (sa.index &&
        sb.index &&
        !sa.middle &&
        !sb.middle &&
        tipGap > 0.12 &&
        tipGap < 0.26) {
      return const SignResult(label: 'hurt', confidence: 0.82, type: 'word');
    }

    return null;
  }

  double _pointGap(HandLandmark a, HandLandmark b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return sqrt(dx * dx + dy * dy);
  }

  SignResult? classifyWords(List<HandLandmark> lm) {
    if (lm.length < 21) return null;
    final s = _shape(lm);
    final wristY = lm[0].y;

    // I LOVE YOU — pinky + thumb out, index/middle/ring curled
    if (!s.index && !s.middle && !s.ring && s.pinky && s.thumbOut) {
      return const SignResult(
          label: 'I love you', confidence: 0.93, type: 'word');
    }

    // THANK YOU — open hand wave (all 4 fingers + thumb, high position, any motion)
    if (s.openFour && s.thumbOut && wristY < 0.55) {
      return const SignResult(
          label: 'thank you', confidence: 0.91, type: 'word');
    }

    // HELLO — open flat hand, no thumb, high (chin level), any flick forward
    if (s.openFour && !s.thumbOut && wristY < 0.50) {
      return const SignResult(label: 'hello', confidence: 0.88, type: 'word');
    }

    // YES — closed fist, no thumb extended (just hold the fist shape)
    if (s.fist && !s.thumbOut && !s.thumbIn) {
      return const SignResult(label: 'yes', confidence: 0.86, type: 'word');
    }

    // NO — index + middle open, touching/near each other, no ring/pinky
    if (s.index && s.middle && !s.ring && !s.pinky && _near(lm, 8, 12, 0.35)) {
      return const SignResult(label: 'no', confidence: 0.86, type: 'word');
    }

    // STOP — open hand (4 fingers + thumb), low position
    if (s.openFour && s.thumbOut && wristY > 0.58) {
      return const SignResult(label: 'stop', confidence: 0.84, type: 'word');
    }

    // PLEASE — open flat hand, no thumb, mid chest position
    if (s.openFour && !s.thumbOut && wristY > 0.48 && wristY < 0.70) {
      return const SignResult(label: 'please', confidence: 0.82, type: 'word');
    }

    // SORRY — closed fist on chest (mid position, thumb in or neutral)
    if (s.fist && s.thumbIn && wristY > 0.42 && wristY < 0.70) {
      return const SignResult(label: 'sorry', confidence: 0.82, type: 'word');
    }

    // EAT — all fingertips close to thumb tip (pinched hand near mouth)
    if (_near(lm, 4, 8, 0.35) &&
        _near(lm, 4, 12, 0.45) &&
        _near(lm, 4, 16, 0.45) &&
        _near(lm, 4, 20, 0.50)) {
      return const SignResult(label: 'eat', confidence: 0.84, type: 'word');
    }

    // DRINK — curved hand (some fingers curled, thumb out), no fully extended fingers
    if (!s.index && !s.middle && !s.ring && !s.pinky && s.thumbOut) {
      return const SignResult(label: 'drink', confidence: 0.82, type: 'word');
    }

    // WHERE — only index up, all others curled, no thumb
    if (s.index &&
        !s.middle &&
        !s.ring &&
        !s.pinky &&
        !s.thumbOut &&
        !s.thumbIn) {
      return const SignResult(label: 'where', confidence: 0.80, type: 'word');
    }

    // WHAT — index up + thumb out (L-shape pointing sideways)
    if (s.index && !s.middle && !s.ring && !s.pinky && s.thumbOut) {
      return const SignResult(label: 'what', confidence: 0.78, type: 'word');
    }

    // WHEN — index + thumb touching (circle shape), others curled
    if (_near(lm, 4, 8, 0.30) && !s.middle && !s.ring && !s.pinky) {
      return const SignResult(label: 'when', confidence: 0.76, type: 'word');
    }

    // BATHROOM — fist with thumb tucked between fingers
    if (s.fist && s.thumbIn && wristY < 0.50) {
      return const SignResult(
          label: 'bathroom', confidence: 0.80, type: 'word');
    }

    // MY — fist with thumb out, mid chest
    if (s.fist && s.thumbOut && wristY > 0.40 && wristY < 0.68) {
      return const SignResult(label: 'my', confidence: 0.76, type: 'word');
    }

    // YOU — index + thumb out, horizontal pointing
    if (s.index && s.thumbOut && !s.middle && !s.ring && !s.pinky) {
      return const SignResult(label: 'you', confidence: 0.76, type: 'word');
    }

    // MORE — index + middle pinched to thumb, ring/pinky curled
    if (_near(lm, 4, 8, 0.32) &&
        _near(lm, 4, 12, 0.42) &&
        !s.ring &&
        !s.pinky) {
      return const SignResult(label: 'more', confidence: 0.80, type: 'word');
    }

    // OPEN — all fingers spread wide, thumb out, spread > 1.1
    if (s.openFour && s.thumbOut && s.spread > 1.10) {
      return const SignResult(label: 'open', confidence: 0.74, type: 'word');
    }

    // GO — index horizontal, no thumb
    if (s.index &&
        !s.middle &&
        !s.ring &&
        !s.pinky &&
        !s.thumbOut &&
        _horizontalFinger(lm, 8, 5)) {
      return const SignResult(label: 'go', confidence: 0.76, type: 'word');
    }

    // FIND — pinched index+thumb, middle/ring/pinky extended
    if (_near(lm, 4, 8, 0.30) && s.middle && s.ring && s.pinky) {
      return const SignResult(label: 'find', confidence: 0.76, type: 'word');
    }

    // SIT — index+middle pointing down
    if (s.index &&
        s.middle &&
        !s.ring &&
        !s.pinky &&
        _downFinger(lm, 8, 5) &&
        _downFinger(lm, 12, 9)) {
      return const SignResult(label: 'sit', confidence: 0.76, type: 'word');
    }

    // SLEEP — open hand, fingers together (low spread), high position
    if (s.openFour && !s.thumbOut && wristY < 0.48 && s.spread < 0.90) {
      return const SignResult(label: 'sleep', confidence: 0.74, type: 'word');
    }

    return null;
  }
}
