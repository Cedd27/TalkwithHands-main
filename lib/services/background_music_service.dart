import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';

final RouteObserver<PageRoute<dynamic>> appRouteObserver =
    RouteObserver<PageRoute<dynamic>>();

enum BackgroundMusicTrack {
  page('audio/Page.mp3'),
  gameHub('audio/game_hub.mp3'),
  guessAsl('audio/Guess_asl.mp3'),
  guessMe('audio/Guess_me.mp3'),
  calculator('audio/Calcu.mp3');

  final String assetPath;
  const BackgroundMusicTrack(this.assetPath);
}

class BackgroundMusicService extends ChangeNotifier
    with WidgetsBindingObserver {
  BackgroundMusicService._();

  static final BackgroundMusicService instance = BackgroundMusicService._();

  final AudioPlayer _player = AudioPlayer(playerId: 'background_music');

  BackgroundMusicTrack? _currentTrack;
  BackgroundMusicTrack? _desiredTrack;
  bool _muted = false;
  bool _backgrounded = false;
  double _volume = 0.45;
  double _outputVolume = 0;
  int _fadeToken = 0;
  bool _initialized = false;

  bool get muted => _muted;
  double get volume => _volume;
  BackgroundMusicTrack? get currentTrack => _currentTrack;

  Future<void> ensureInitialized() async {
    if (_initialized) return;
    _initialized = true;
    WidgetsBinding.instance.addObserver(this);
    await _player.setReleaseMode(ReleaseMode.loop);
    await _player.setPlayerMode(PlayerMode.mediaPlayer);
    _outputVolume = _muted ? 0 : _volume;
    await _player.setVolume(_outputVolume);
  }

  Future<void> play(BackgroundMusicTrack track) async {
    await ensureInitialized();
    _desiredTrack = track;
    if (_backgrounded) return;

    if (_currentTrack == track) {
      await _player.resume();
      await _fadeTo(_muted ? 0 : _volume);
      return;
    }

    final token = ++_fadeToken;
    if (_currentTrack != null) {
      await _fadeTo(0, token: token);
      if (token != _fadeToken) return;
    }

    _currentTrack = track;
    await _player.stop();
    await _player.setReleaseMode(ReleaseMode.loop);
    _outputVolume = 0;
    await _player.setVolume(_outputVolume);
    await _player.play(AssetSource(track.assetPath));
    await _fadeTo(_muted ? 0 : _volume, token: token);
  }

  Future<void> pause() async {
    await ensureInitialized();
    _desiredTrack = null;
    await _fadeTo(0);
    await _player.pause();
  }

  Future<void> toggleMuted() async {
    await setMuted(!_muted);
  }

  Future<void> setMuted(bool muted) async {
    await ensureInitialized();
    if (_muted == muted) return;
    _muted = muted;
    notifyListeners();
    await _fadeTo(_muted ? 0 : _volume);
  }

  Future<void> setVolume(double volume) async {
    await ensureInitialized();
    _volume = volume.clamp(0, 1);
    if (!_muted) await _fadeTo(_volume);
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _backgrounded = true;
      unawaited(_player.pause());
      return;
    }

    if (state == AppLifecycleState.resumed) {
      _backgrounded = false;
      final track = _desiredTrack;
      if (track != null) {
        unawaited(play(track));
      }
    }
  }

  Future<void> _fadeTo(double target, {int? token}) async {
    final activeToken = token ?? ++_fadeToken;
    final safeTarget = target.clamp(0, 1).toDouble();
    const steps = 8;
    const stepDelay = Duration(milliseconds: 24);
    final start = _outputVolume;

    for (var i = 1; i <= steps; i++) {
      if (activeToken != _fadeToken) return;
      final value = start + (safeTarget - start) * (i / steps);
      _outputVolume = value;
      await _player.setVolume(value);
      await Future<void>.delayed(stepDelay);
    }
  }
}
