import 'dart:async';
import 'dart:developer' as dev;

import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'auth_service.dart';
import 'progress_service.dart';

class ActivityTimeService with WidgetsBindingObserver {
  ActivityTimeService._();

  static final ActivityTimeService instance = ActivityTimeService._();
  static const _storage = FlutterSecureStorage();
  static const _dailyLimitSeconds = 24 * 60 * 60;
  static const _flushInterval = Duration(seconds: 60);

  Timer? _timer;
  Timer? _displayTimer;
  DateTime? _activeSince;
  String? _sessionDateKey;
  String? _sessionScopeKey;
  int _localTodaySeconds = 0;
  bool _started = false;
  bool _flushing = false;
  final ValueNotifier<int> liveSessionSeconds = ValueNotifier<int>(0);

  void start() {
    if (_started) return;
    _started = true;
    final now = DateTime.now();
    _sessionDateKey = _todayKey(now);
    WidgetsBinding.instance.addObserver(this);
    unawaited(_loadLocalTodaySeconds(now));
    _resume();
  }

  Future<void> prepareForAccountChange() async {
    await _flush();
    _sessionDateKey = null;
    _sessionScopeKey = null;
    _localTodaySeconds = 0;
    _activeSince = DateTime.now();
    liveSessionSeconds.value = 0;
  }

  Future<void> reloadForCurrentAccount() async {
    final now = DateTime.now();
    _sessionDateKey = null;
    _sessionScopeKey = null;
    await _syncScopeAndDay(now);
    _activeSince = now;
    _publishLiveTodaySeconds(now);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _resume();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_flush());
      _timer?.cancel();
      _activeSince = null;
    }
  }

  void _resume() {
    final now = DateTime.now();
    unawaited(_syncScopeAndDay(now));
    _activeSince ??= now;
    _timer?.cancel();
    _timer = Timer.periodic(_flushInterval, (_) => unawaited(_flush()));
    _displayTimer?.cancel();
    _displayTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final now = DateTime.now();
      unawaited(_syncScopeAndDay(now));
      _publishLiveTodaySeconds(now);
    });
  }

  Future<void> _syncScopeAndDay(DateTime now) async {
    final today = _todayKey(now);
    final scope = await _accountScope();
    if (_sessionDateKey == today && _sessionScopeKey == scope) return;
    _sessionDateKey = today;
    _sessionScopeKey = scope;
    _localTodaySeconds = 0;
    _activeSince = now;
    liveSessionSeconds.value = 0;
    await _loadLocalTodaySeconds(now, scope: scope);
  }

  Future<void> _loadLocalTodaySeconds(DateTime now, {String? scope}) async {
    final todayKey = _todayKey(now);
    final accountScope = scope ?? await _accountScope();
    _sessionScopeKey = accountScope;
    final storageKey = _activityStorageKey(accountScope, todayKey);
    final storedSeconds =
        int.tryParse(await _storage.read(key: storageKey) ?? '0') ?? 0;
    if (storedSeconds >= _dailyLimitSeconds) {
      _localTodaySeconds = 0;
      await _storage.write(key: storageKey, value: '0');
    } else {
      _localTodaySeconds =
          storedSeconds.clamp(0, _dailyLimitSeconds).toInt();
    }
    _publishLiveTodaySeconds(DateTime.now());
  }

  void _publishLiveTodaySeconds(DateTime now) {
    final activeStartedAt = _activeSince;
    final activeSeconds = activeStartedAt == null
        ? 0
        : now
            .difference(activeStartedAt)
            .inSeconds
            .clamp(0, _dailyLimitSeconds)
            .toInt();
    liveSessionSeconds.value =
        (_localTodaySeconds + activeSeconds)
            .clamp(0, _dailyLimitSeconds)
            .toInt();
  }

  Future<void> _flush() async {
    if (_flushing) return;
    final startedAt = _activeSince;
    if (startedAt == null) return;

    final now = DateTime.now();
    final elapsed = now.difference(startedAt).inSeconds;
    if (elapsed <= 0) return;

    final todayKey = _todayKey(now);
    final accountScope = await _accountScope();
    if (_sessionDateKey != todayKey || _sessionScopeKey != accountScope) {
      _sessionDateKey = todayKey;
      _sessionScopeKey = accountScope;
      _localTodaySeconds = 0;
      _activeSince = now;
      liveSessionSeconds.value = 0;
      await _loadLocalTodaySeconds(now, scope: accountScope);
      return;
    }

    _activeSince = now;
    final storageKey = _activityStorageKey(accountScope, todayKey);
    final storedSeconds =
        int.tryParse(await _storage.read(key: storageKey) ?? '0') ?? 0;
    final remaining = _dailyLimitSeconds - storedSeconds;
    if (remaining <= 0) return;

    final secondsToRecord = elapsed.clamp(0, remaining).toInt();
    if (secondsToRecord <= 0) return;

    _flushing = true;
    try {
      await ProgressService().recordActivity(
        category: 'detector',
        secondsSpent: secondsToRecord,
        countEvent: false,
      );
      await _storage.write(
        key: storageKey,
        value: '${storedSeconds + secondsToRecord}',
      );
      _localTodaySeconds = storedSeconds + secondsToRecord;
      _publishLiveTodaySeconds(now);
    } catch (e) {
      dev.log(
        'Activity time sync skipped',
        name: 'ActivityTimeService',
        error: e,
      );
      _activeSince = startedAt;
    } finally {
      _flushing = false;
    }
  }

  String _todayKey(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  Future<String> _accountScope() async {
    final profile = await AuthService.cachedProfile();
    final raw = (profile?.id.trim().isNotEmpty ?? false)
        ? profile!.id.trim()
        : (profile?.email ?? '').trim();
    return _sanitizeScope(raw.isEmpty ? 'guest' : raw);
  }

  String _activityStorageKey(String accountScope, String dateKey) {
    return 'activity_seconds_${accountScope}_$dateKey';
  }

  String _sanitizeScope(String value) {
    return value.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
  }
}
