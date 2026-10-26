import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../classifiers/sign_classifier.dart';

const List<List<int>> handConnections = [
  [0, 1], [1, 2], [2, 3], [3, 4],
  [0, 5], [5, 6], [6, 7], [7, 8],
  [0, 9], [9, 10], [10, 11], [11, 12],
  [0, 13], [13, 14], [14, 15], [15, 16],
  [0, 17], [17, 18], [18, 19], [19, 20],
  [5, 9], [9, 13], [13, 17],
];

class LandmarkPainter extends CustomPainter {
  final List<HandLandmark>? handLandmarks;
  final List<List<HandLandmark>>? handsLandmarks;
  final Size previewSize;
  final CameraLensDirection lensDirection;
  final int sensorOrientation;

  const LandmarkPainter({
    this.handLandmarks,
    this.handsLandmarks,
    this.previewSize = Size.zero,
    this.lensDirection = CameraLensDirection.front,
    this.sensorOrientation = 0,
  });

  // ─── Cached Paint objects — created once, reused every frame ───────────────
  static final Paint _boxPaintHand0 = Paint()
    ..color = const Color(0xFF00E5CC)
    ..strokeWidth = 2.0
    ..style = PaintingStyle.stroke;

  static final Paint _boxPaintHand1 = Paint()
    ..color = const Color(0xFF4BA3FF)
    ..strokeWidth = 2.0
    ..style = PaintingStyle.stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final hands = handsLandmarks ??
        (handLandmarks == null ? null : <List<HandLandmark>>[handLandmarks!]);
    if (hands == null || hands.isEmpty) return;

    canvas.save();
    final paintScale = _applyCameraTransform(canvas, size);

    for (var handIndex = 0; handIndex < hands.length; handIndex++) {
      final landmarks = hands[handIndex];
      if (landmarks.length < 21) continue;
      _paintHand(canvas, landmarks, paintScale, handIndex);
    }

    canvas.restore();
  }

  void _paintHand(
    Canvas canvas,
    List<HandLandmark> landmarks,
    double scale,
    int handIndex,
  ) {
    final boxPaint = handIndex == 0 ? _boxPaintHand0 : _boxPaintHand1;
    boxPaint.strokeWidth = 2.0 / scale;

    // ── Bounding box only — no dots, no lines ────────────────────────────────
    double minX = double.infinity;
    double maxX = double.negativeInfinity;
    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    for (var i = 0; i < landmarks.length; i++) {
      final point = _toPreviewPoint(landmarks[i].x, landmarks[i].y);
      if (point.dx < minX) minX = point.dx;
      if (point.dx > maxX) maxX = point.dx;
      if (point.dy < minY) minY = point.dy;
      if (point.dy > maxY) maxY = point.dy;
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          minX - 12,
          minY - 12,
          (maxX - minX) + 24,
          (maxY - minY) + 24,
        ),
        Radius.circular(8 / scale),
      ),
      boxPaint,
    );
  }

  Size get _rawPreviewSize =>
      previewSize == Size.zero ? const Size(1, 1) : previewSize;

  double _applyCameraTransform(Canvas canvas, Size size) {
    final raw = _rawPreviewSize;
    // Scale to fit the rotated preview into the widget
    final scale = size.width / raw.height;
    final center = Offset(size.width / 2, size.height / 2);

    canvas.translate(center.dx, center.dy);

    if (lensDirection == CameraLensDirection.front) {
      // Front camera: mirror horizontally THEN apply sensor rotation
      canvas.scale(-1.0, 1.0);
    }

    canvas.rotate(sensorOrientation * math.pi / 180);
    canvas.scale(scale);
    return scale;
  }

  Offset _toPreviewPoint(double x, double y) {
    final raw = _rawPreviewSize;
    return Offset(
      (x - 0.5) * raw.width,
      (y - 0.5) * raw.height,
    );
  }

  // ─── VALUE-BASED comparison — prevents unnecessary repaints ────────────────
  @override
  bool shouldRepaint(LandmarkPainter old) {
    // Cheap scalar checks first
    if (old.previewSize != previewSize ||
        old.lensDirection != lensDirection ||
        old.sensorOrientation != sensorOrientation) {
      return true;
    }

    // Deep-compare handsLandmarks
    final oldHands = old.handsLandmarks;
    final newHands = handsLandmarks;
    if (!identical(oldHands, newHands)) {
      if (oldHands == null || newHands == null) return true;
      if (oldHands.length != newHands.length) return true;
      for (var h = 0; h < newHands.length; h++) {
        final oldLm = oldHands[h];
        final newLm = newHands[h];
        if (oldLm.length != newLm.length) return true;
        for (var i = 0; i < newLm.length; i++) {
          // Compare by value — not by reference
          if (oldLm[i].x != newLm[i].x || oldLm[i].y != newLm[i].y) {
            return true;
          }
        }
      }
    }

    // Deep-compare single-hand list
    final oldSingle = old.handLandmarks;
    final newSingle = handLandmarks;
    if (!identical(oldSingle, newSingle)) {
      if (oldSingle == null || newSingle == null) return true;
      if (oldSingle.length != newSingle.length) return true;
      for (var i = 0; i < newSingle.length; i++) {
        if (oldSingle[i].x != newSingle[i].x ||
            oldSingle[i].y != newSingle[i].y) {
          return true;
        }
      }
    }

    return false; // identical data → skip repaint
  }
}