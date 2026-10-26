import 'dart:async';
import 'dart:isolate';

import 'package:camera/camera.dart';
import 'package:hand_landmarker/hand_landmarker.dart' as mp_hand;

/// hand_landmarker's `HandLandmarkerPlugin.detect(...)` is a synchronous
/// Dart call (not a Future) — so no matter how fast the native/Kotlin side
/// is, calling it directly blocks the calling isolate until it returns.
/// When that's the main/UI isolate, Flutter can't build or paint a new
/// frame while it waits, which freezes the *entire* screen (camera preview
/// included), not just the landmark overlay.
///
/// This worker runs one persistent background isolate (spawned once, not
/// per frame — spawning per frame would add its own overhead) and routes
/// every detect() call through it, so the UI isolate is always free to
/// keep painting at full speed.
class HandLandmarkWorker {
  final ReceivePort _receivePort = ReceivePort();
  StreamSubscription? _subscription;
  Isolate? _isolate;
  SendPort? _commandPort;
  Completer<void>? _readyCompleter;
  final Map<int, Completer<List<mp_hand.Hand>>> _pending = {};
  int _nextId = 0;
  bool _busy = false;

  bool get isReady => _commandPort != null;
  bool get isBusy => _busy;

  Future<void> start({
    required int numHands,
    required double minHandDetectionConfidence,
    required mp_hand.HandLandmarkerDelegate delegate,
  }) async {
    _readyCompleter = Completer<void>();

    _subscription = _receivePort.listen((message) {
      if (message is SendPort) {
        _commandPort = message;
        _readyCompleter?.complete();
      } else if (message is _DetectResponse) {
        final completer = _pending.remove(message.id);
        _busy = false;
        if (completer == null) return;
        if (message.error != null) {
          completer.completeError(message.error!);
        } else {
          completer.complete(message.hands);
        }
      }
    });

    _isolate = await Isolate.spawn(
      _isolateEntry,
      _InitMessage(
        _receivePort.sendPort,
        numHands,
        minHandDetectionConfidence,
        delegate,
      ),
    );

    await _readyCompleter!.future;
  }

  /// Returns an empty list if the worker isn't ready yet or is still busy
  /// with a previous frame — callers should treat that as "skip this
  /// frame" rather than queueing, so a slow device doesn't build a backlog.
  Future<List<mp_hand.Hand>> detect(
    CameraImage image,
    int sensorOrientation,
  ) {
    final commandPort = _commandPort;
    if (commandPort == null || _busy) {
      return Future.value(const []);
    }
    final id = _nextId++;
    final completer = Completer<List<mp_hand.Hand>>();
    _pending[id] = completer;
    _busy = true;
    commandPort.send(_DetectRequest(id, image, sensorOrientation));
    return completer.future;
  }

  void dispose() {
    _subscription?.cancel();
    _receivePort.close();
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _commandPort = null;
    for (final completer in _pending.values) {
      if (!completer.isCompleted) {
        completer.complete(const []);
      }
    }
    _pending.clear();
  }

  static void _isolateEntry(_InitMessage init) {
    final commandPort = ReceivePort();
    init.mainSendPort.send(commandPort.sendPort);

    final plugin = mp_hand.HandLandmarkerPlugin.create(
      numHands: init.numHands,
      minHandDetectionConfidence: init.minHandDetectionConfidence,
      delegate: init.delegate,
    );

    commandPort.listen((message) {
      if (message is _DetectRequest) {
        try {
          final hands = plugin.detect(message.image, message.sensorOrientation);
          init.mainSendPort.send(_DetectResponse(message.id, hands));
        } catch (e) {
          init.mainSendPort.send(_DetectResponse(message.id, const [], e));
        }
      }
    });
  }
}

class _InitMessage {
  final SendPort mainSendPort;
  final int numHands;
  final double minHandDetectionConfidence;
  final mp_hand.HandLandmarkerDelegate delegate;
  _InitMessage(
    this.mainSendPort,
    this.numHands,
    this.minHandDetectionConfidence,
    this.delegate,
  );
}

class _DetectRequest {
  final int id;
  final CameraImage image;
  final int sensorOrientation;
  _DetectRequest(this.id, this.image, this.sensorOrientation);
}

class _DetectResponse {
  final int id;
  final List<mp_hand.Hand> hands;
  final Object? error;
  _DetectResponse(this.id, this.hands, [this.error]);
}