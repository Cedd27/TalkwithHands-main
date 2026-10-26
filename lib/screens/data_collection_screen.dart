import 'dart:convert';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hand_landmarker/hand_landmarker.dart' as mp_hand;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../classifiers/sign_classifier.dart';
import '../painters/landmark_painter.dart';
import '../ui/background_music_region.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────
const Color kBg = Color(0xFF0A0E1A);
const Color kTeal = Color(0xFF00E5CC);
const Color kTealDim = Color(0x4000E5CC);
const Color kTealBorder = Color(0x8000E5CC);
const Color kRed = Color(0xFFFF4D6A);
const Color kOrange = Color(0xFFFF9500);

// ─── Static labels (snapshot) ─────────────────────────────────────────────────
const List<String> kFallbackStaticLabels = [
  'A','B','C','D','E','F','G','H','I',
  'K','L','M','N','O','P','Q','R','S','T',
  'U','V','W','X','Y',
  '0','1','2','3','4','5','6','7','8','9',
  '10','11','12','13','14','15','16','17','18','19','20',
  'yes','no','stop','more','need','want',
  'good','bad','love','me','you','i',
];

// ─── Dynamic labels (sequence) ────────────────────────────────────────────────
const List<String> kFallbackDynamicLabels = [
  'J','Z',
  'hello','thank you','please','sorry',
  'help','come','go','eat','drink','water',
  'i love you','friend','home','work','school',
  'play','run','learn','find','feel',
];

const int kSamplesPerLabel = 20;
const int kCaptureCooldownMs = 300;

/// How many frames make up one sequence sample.
const int kSequenceFrames = 20;

/// Gap between frame captures when recording a sequence (~10fps).
const int kSequenceFrameMs = 100;

// ─────────────────────────────────────────────────────────────────────────────

enum _CollectMode { static_, sequence }

class DataCollectionScreen extends StatefulWidget {
  const DataCollectionScreen({super.key});

  @override
  State<DataCollectionScreen> createState() => _DataCollectionScreenState();
}

class _DataCollectionScreenState extends State<DataCollectionScreen>
    with WidgetsBindingObserver {
  static const _exportsChannel = MethodChannel('talkwithhands/training_exports');

  // Camera
  CameraController? _cameraController;
  bool _cameraInitialized = false;
  bool _streaming = false;
  bool _processing = false;
  int _frameCounter = 0;
  DateTime _lastInferenceAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastUiUpdateAt = DateTime.fromMillisecondsSinceEpoch(0);

  // MediaPipe
  late final mp_hand.HandLandmarkerPlugin _handLandmarker;

  // UI / loading
  bool _loading = true;
  String _loadText = 'Initializing...';
  List<HandLandmark>? _handLandmarks;
  Size? _displayPreviewSize;
  int _sensorOrientation = 0;
  List<String> _staticLabels = kFallbackStaticLabels;
  List<String> _dynamicLabels = kFallbackDynamicLabels;
  String _staticSearchQuery = '';

  // Collection mode
  _CollectMode _collectMode = _CollectMode.static_;

  // Static state
  String _staticLabel = kFallbackStaticLabels.first;
  bool _staticRecording = false;
  DateTime _lastStaticCapture = DateTime.fromMillisecondsSinceEpoch(0);

  // Sequence state
  String _seqLabel = kFallbackDynamicLabels.first;
  bool _seqRecording = false;
  DateTime _lastSeqFrame = DateTime.fromMillisecondsSinceEpoch(0);
  final List<List<HandLandmark>> _seqBuffer = [];

  // Shared counts & feedback
  final Map<String, int> _counts = {};
  int _totalWritten = 0;
  bool _flashVisible = false;

  // CSV paths
  String? _staticCsvPath;
  String? _seqCsvPath;

  bool get _isAndroid => !kIsWeb && Platform.isAndroid;

  // ── Init ──────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _handLandmarker = mp_hand.HandLandmarkerPlugin.create(
      numHands: 1,
      minHandDetectionConfidence: 0.55,
      delegate: mp_hand.HandLandmarkerDelegate.cpu,
    );
    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopStream();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) _stopStream();
    if (state == AppLifecycleState.resumed && _cameraInitialized) _startStream();
  }

  Future<void> _init() async {
    if (!_isAndroid) {
      setState(() { _loadText = 'Android device required.'; _loading = false; });
      return;
    }
    await _loadCollectionLabels();
    await _resolvePaths();
    await _requestCamera();
  }

  Future<void> _loadCollectionLabels() async {
    try {
      final raw = await rootBundle.loadString('backend/data/basic-words.json');
      final data = jsonDecode(raw);
      if (data is! List) return;

      final numbers = <String>{
        for (var number = 0; number <= 20; number++) number.toString(),
      };
      final basicWords = <String>{};
      for (final item in data.whereType<Map>()) {
        final category = (item['category'] ?? '').toString().trim().toLowerCase();
        final title = (item['title'] ?? '').toString().trim();
        if (title.isEmpty) continue;
        if (category == 'alphabet') continue;
        if (category == 'number' || category == 'numbers') {
          numbers.add(title);
        } else {
          basicWords.add(title);
        }
      }

      final sortedNumbers = numbers.toList()
        ..sort((a, b) {
          final left = int.tryParse(a);
          final right = int.tryParse(b);
          if (left != null && right != null) return left.compareTo(right);
          return a.compareTo(b);
        });
      final sortedBasicWords = basicWords.toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

      if (sortedBasicWords.isEmpty || !mounted) return;
      setState(() {
        _staticLabels = [
          ...kFallbackStaticLabels.where((label) => int.tryParse(label) == null),
          ...sortedNumbers,
          ...sortedBasicWords,
        ];
        _dynamicLabels = ['J', 'Z', ...sortedBasicWords];
        if (!_staticLabels.contains(_staticLabel)) {
          _staticLabel = _staticLabels.first;
        }
        if (!_dynamicLabels.contains(_seqLabel)) {
          _seqLabel = _dynamicLabels.first;
        }
      });
    } catch (e) {
      debugPrint('Collection label load error: $e');
    }
  }

  Future<void> _resolvePaths() async {
    try {
      final ext = await getExternalStorageDirectory();
      if (ext != null) {
        final dir = Directory('${ext.path}/sign_data');
        await dir.create(recursive: true);

        // Static CSV
        _staticCsvPath = '${dir.path}/sign_landmarks.csv';
        final staticFile = File(_staticCsvPath!);
        if (!staticFile.existsSync()) {
          final cols = List.generate(21, (i) => 'x$i,y$i,z$i').join(',');
          await staticFile.writeAsString('label,$cols\n');
        }

        // Sequence CSV — each row = label + 30 frames * 63 values
        _seqCsvPath = '${dir.path}/sign_sequences.csv';
        final seqFile = File(_seqCsvPath!);
        if (!seqFile.existsSync()) {
          final cols = List.generate(
            kSequenceFrames,
            (f) => List.generate(21, (i) => 'f${f}_x$i,f${f}_y$i,f${f}_z$i').join(','),
          ).join(',');
          await seqFile.writeAsString('label,$cols\n');
        }
      }
    } catch (e) {
      debugPrint('Path error: $e');
    }
  }

  Future<void> _requestCamera() async {
    setState(() => _loadText = 'Requesting camera permission...');
    final status = await Permission.camera.request();
    if (status.isGranted) {
      await _initCamera();
    } else {
      setState(() { _loadText = 'Camera permission denied.'; _loading = false; });
    }
  }

  Future<void> _initCamera() async {
    setState(() => _loadText = 'Starting camera...');
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() { _loadText = 'No cameras found.'; _loading = false; });
        return;
      }
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        camera, ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await controller.initialize();
      await _cameraController?.dispose();
      _cameraController = controller;
      _sensorOrientation = camera.sensorOrientation;

      final ps = controller.value.previewSize;
      if (ps != null) _displayPreviewSize = Size(ps.height, ps.width);

      setState(() { _cameraInitialized = true; _loading = false; });
      await _startStream();
    } catch (e) {
      setState(() { _loadText = 'Camera error: $e'; _loading = false; });
    }
  }

  // ── Stream ────────────────────────────────────────────────────────────────

  Future<void> _startStream() async {
    final c = _cameraController;
    if (c == null || _streaming || !c.value.isInitialized) return;
    await c.startImageStream(_onFrame);
    _streaming = true;
  }

  Future<void> _stopStream() async {
    final c = _cameraController;
    if (c == null || !_streaming) return;
    try { await c.stopImageStream(); } catch (_) {}
    _streaming = false;
    _processing = false;
  }

  void _onFrame(CameraImage image) {
    if (_processing || !_cameraInitialized) return;
    _frameCounter++;
    if (_frameCounter % 8 != 0) return;
    final now = DateTime.now();
    if (now.difference(_lastInferenceAt) < const Duration(milliseconds: 220)) return;
    _lastInferenceAt = now;
    _processFrame(image, now);
  }

  Future<void> _processFrame(CameraImage image, DateTime now) async {
    _processing = true;
    try {
      if (image.planes.length < 3) return;
      List<HandLandmark>? landmarks;
      try {
        final detected = _handLandmarker.detect(image, _sensorOrientation);
        if (detected.isNotEmpty) {
          landmarks = detected.first.landmarks
              .map((lm) => HandLandmark(lm.x, lm.y, lm.z))
              .toList(growable: false);
        }
      } catch (e) {
        debugPrint('Detection error: $e');
      }

      if (!mounted) return;
      final handPresenceChanged = (landmarks == null) != (_handLandmarks == null);
      _handLandmarks = landmarks;
      if (handPresenceChanged ||
          now.difference(_lastUiUpdateAt) >= const Duration(milliseconds: 180)) {
        _lastUiUpdateAt = now;
        setState(() {});
      }

      if (landmarks == null) return;

      // ── Static auto-capture ──────────────────────────────────────────────
      if (_staticRecording &&
          _collectMode == _CollectMode.static_ &&
          now.difference(_lastStaticCapture).inMilliseconds >= kCaptureCooldownMs) {
        _lastStaticCapture = now;
        await _saveStaticSample(landmarks);
      }

      // ── Sequence frame capture ───────────────────────────────────────────
      if (_seqRecording &&
          _collectMode == _CollectMode.sequence &&
          now.difference(_lastSeqFrame).inMilliseconds >= kSequenceFrameMs) {
        _lastSeqFrame = now;
        _seqBuffer.add(List<HandLandmark>.from(landmarks));
        if (mounted) setState(() {}); // update progress indicator

        if (_seqBuffer.length >= kSequenceFrames) {
          _seqRecording = false;
          await _saveSequenceSample(List<List<HandLandmark>>.from(_seqBuffer));
          _seqBuffer.clear();
        }
      }
    } finally {
      _processing = false;
    }
  }

  // ── Save static ───────────────────────────────────────────────────────────

  Future<void> _saveStaticSample(List<HandLandmark> landmarks) async {
    if (_staticCsvPath == null) return;
    final values = landmarks
        .map((lm) => '${lm.x.toStringAsFixed(6)},${lm.y.toStringAsFixed(6)},${lm.z.toStringAsFixed(6)}')
        .join(',');
    try {
      await File(_staticCsvPath!).writeAsString('$_staticLabel,$values\n', mode: FileMode.append);
      setState(() {
        _counts[_staticLabel] = (_counts[_staticLabel] ?? 0) + 1;
        _totalWritten++;
        _flashVisible = true;
      });
      Future.delayed(const Duration(milliseconds: 120), () {
        if (mounted) setState(() => _flashVisible = false);
      });
      if ((_counts[_staticLabel] ?? 0) >= kSamplesPerLabel && _staticRecording) {
        setState(() => _staticRecording = false);
        _showSnack('✓ $_staticLabel complete — $kSamplesPerLabel samples saved');
      }
    } catch (e) {
      debugPrint('Static write error: $e');
    }
  }

  // ── Save sequence ─────────────────────────────────────────────────────────

  Future<void> _saveSequenceSample(List<List<HandLandmark>> frames) async {
    if (_seqCsvPath == null) return;
    final sb = StringBuffer()..write(_seqLabel);
    for (final frame in frames) {
      for (final lm in frame) {
        sb.write(',${lm.x.toStringAsFixed(6)},${lm.y.toStringAsFixed(6)},${lm.z.toStringAsFixed(6)}');
      }
    }
    sb.write('\n');
    try {
      await File(_seqCsvPath!).writeAsString(sb.toString(), mode: FileMode.append);
      setState(() {
        _counts[_seqLabel] = (_counts[_seqLabel] ?? 0) + 1;
        _totalWritten++;
        _flashVisible = true;
      });
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) setState(() => _flashVisible = false);
      });
      _showSnack('✓ Sequence #${_counts[_seqLabel]} saved for "$_seqLabel"');
      if ((_counts[_seqLabel] ?? 0) >= kSamplesPerLabel) {
        _showSnack('✓ "$_seqLabel" complete — $kSamplesPerLabel sequences!');
      }
    } catch (e) {
      debugPrint('Sequence write error: $e');
    }
  }

  void _captureStaticOnce() {
    final lm = _handLandmarks;
    if (lm == null) { _showSnack('No hand detected.'); return; }
    _saveStaticSample(lm);
  }

  void _startSequence() {
    final lm = _handLandmarks;
    if (lm == null) { _showSnack('Show your hand first.'); return; }
    if ((_counts[_seqLabel] ?? 0) >= kSamplesPerLabel) {
      _showSnack('"$_seqLabel" already complete.'); return;
    }
    setState(() {
      _seqBuffer.clear();
      _seqRecording = true;
    });
    _showSnack('Recording — do the sign now!');
  }

  void _cancelSequence() {
    setState(() { _seqRecording = false; _seqBuffer.clear(); });
  }

  String? get _currentCsvPath =>
      _collectMode == _CollectMode.sequence ? _seqCsvPath : _staticCsvPath;

  String get _currentCsvName =>
      _collectMode == _CollectMode.sequence ? 'sign_sequences.csv' : 'sign_landmarks.csv';

  Future<void> _exportCurrentCsv() async {
    final path = _currentCsvPath;
    if (path == null) {
      _showSnack('CSV file is not ready yet.');
      return;
    }

    final file = File(path);
    if (!await file.exists()) {
      _showSnack('CSV file was not found yet.');
      return;
    }

    try {
      final exportedPath = await _exportsChannel.invokeMethod<String>(
        'exportCsvToDownloads',
        {
          'sourcePath': path,
          'fileName': _currentCsvName,
        },
      );
      _showSnack('Exported to ${exportedPath ?? 'Downloads'}');
    } on PlatformException catch (e) {
      _showSnack(e.message ?? 'Export failed.');
    } catch (e) {
      _showSnack('Export failed: $e');
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white, fontSize: 13)),
      backgroundColor: const Color(0xFF1A1F2E),
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: kTealDim, width: 0.5),
      ),
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: BackgroundMusicRegion(
        track: null,
        showToggle: false,
        child: _loading ? _buildLoading() : _buildMain(),
      ),
    );
  }

  Widget _buildLoading() => Container(
    color: kBg,
    child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const SizedBox(width: 44, height: 44,
        child: CircularProgressIndicator(color: kTeal, strokeWidth: 3)),
      const SizedBox(height: 16),
      Text(_loadText, style: const TextStyle(color: Color(0x88FFFFFF), fontSize: 14),
        textAlign: TextAlign.center),
    ])),
  );

  Widget _buildMain() => SafeArea(
    child: Column(children: [
      _buildTopBar(),
      _buildModeTabs(),
      Expanded(child: _buildCamera()),
      _collectMode == _CollectMode.static_ ? _buildStaticPanel() : _buildSequencePanel(),
    ]),
  );

  // ── Top bar ───────────────────────────────────────────────────────────────

  Widget _buildTopBar() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: const BoxDecoration(
      color: Color(0xCC0A0E1A),
      border: Border(bottom: BorderSide(color: Color(0x1AFFFFFF), width: 0.5)),
    ),
    child: Row(children: [
      GestureDetector(
        onTap: () => Navigator.of(context).maybePop(),
        child: const Icon(Icons.arrow_back_ios_new, color: Color(0x99FFFFFF), size: 18),
      ),
      const SizedBox(width: 10),
      const Text('Collect Training Data',
        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
      const Spacer(),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0x2200E5CC),
          border: Border.all(color: kTealBorder, width: 0.5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text('$_totalWritten total',
          style: const TextStyle(color: kTeal, fontSize: 11, fontWeight: FontWeight.w700)),
      ),
    ]),
  );

  // ── Mode tabs ─────────────────────────────────────────────────────────────

  Widget _buildModeTabs() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Color(0x1AFFFFFF), width: 0.5)),
    ),
    child: Row(children: [
      _ModeTab(
        label: '📸  Static signs',
        subtitle: 'A-Z, 0-20, yes, no...',
        active: _collectMode == _CollectMode.static_,
        color: kTeal,
        onTap: () => setState(() { _collectMode = _CollectMode.static_; _staticRecording = false; _seqRecording = false; }),
      ),
      const SizedBox(width: 8),
      _ModeTab(
        label: '🎬  Motion signs',
        subtitle: 'Full basic words',
        active: _collectMode == _CollectMode.sequence,
        color: kOrange,
        onTap: () => setState(() { _collectMode = _CollectMode.sequence; _staticRecording = false; _seqRecording = false; }),
      ),
    ]),
  );

  // ── Camera ────────────────────────────────────────────────────────────────

  Widget _buildCamera() {
    final controller = _cameraController;
    if (controller == null || !_cameraInitialized) {
      return const Center(child: Text('Camera unavailable',
        style: TextStyle(color: Color(0x66FFFFFF))));
    }
    return LayoutBuilder(builder: (context, constraints) {
      return Stack(fit: StackFit.expand, children: [
        ClipRect(child: OverflowBox(
          alignment: Alignment.center,
          child: FittedBox(fit: BoxFit.cover,
            child: SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxWidth *
                (controller.value.aspectRatio > 0 ? 1 / controller.value.aspectRatio : 16 / 9),
              child: CameraPreview(controller),
            )),
        )),

        if (_handLandmarks != null && _displayPreviewSize != null)
          CustomPaint(painter: LandmarkPainter(
            handLandmarks: _handLandmarks,
            previewSize: _displayPreviewSize!,
            lensDirection: CameraLensDirection.front,
            sensorOrientation: _sensorOrientation,
          )),

        if (_flashVisible)
          Container(color: const Color(0x3300E5CC)),

        // No hand badge
        if (_handLandmarks == null)
          Align(alignment: Alignment.topCenter,
            child: Padding(padding: const EdgeInsets.only(top: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xCC0A0E1A),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0x33FFFFFF), width: 0.5),
                ),
                child: const Text('✋  Show your hand',
                  style: TextStyle(color: Color(0x99FFFFFF), fontSize: 12)),
              ))),

        // Sequence progress ring
        if (_collectMode == _CollectMode.sequence && _seqRecording)
          Center(child: _SequenceRing(
            progress: _seqBuffer.length / kSequenceFrames,
            framesLeft: kSequenceFrames - _seqBuffer.length,
          )),

        // Recording dot (static)
        if (_collectMode == _CollectMode.static_ && _staticRecording)
          const Positioned(top: 14, right: 14, child: _PulsingDot(color: kRed)),

        // Label watermark
        Positioned(
          bottom: 12, left: 0, right: 0,
          child: Center(child: Text(
            (_collectMode == _CollectMode.static_ ? _staticLabel : _seqLabel).toUpperCase(),
            style: const TextStyle(
              color: Color(0x2200E5CC), fontSize: 80,
              fontWeight: FontWeight.w900, height: 1),
          )),
        ),
      ]);
    });
  }

  // ── Static panel ──────────────────────────────────────────────────────────

  Widget _buildStaticPanel() {
    final count = _counts[_staticLabel] ?? 0;
    final done = count >= kSamplesPerLabel;
    final filteredLabels = _staticLabels
        .where((label) => label
            .toLowerCase()
            .contains(_staticSearchQuery.trim().toLowerCase()))
        .toList();

    return _BottomPanel(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: const Color(0x14FFFFFF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0x1AFFFFFF), width: 0.5),
        ),
        child: Row(children: [
          const Icon(Icons.search, color: Color(0x66FFFFFF), size: 15),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              onChanged: (value) => setState(() => _staticSearchQuery = value),
              style: const TextStyle(color: Colors.white, fontSize: 12),
              decoration: const InputDecoration(
                hintText: 'Search labels...',
                hintStyle: TextStyle(color: Color(0x66FFFFFF), fontSize: 12),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          if (_staticSearchQuery.trim().isNotEmpty)
            GestureDetector(
              onTap: () => setState(() => _staticSearchQuery = ''),
              child: const Icon(Icons.clear, color: Color(0x99FFFFFF), size: 15),
            ),
        ]),
      ),
      const SizedBox(height: 10),
      if (filteredLabels.isEmpty)
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            'No matching labels found.',
            style: TextStyle(color: Color(0x66FFFFFF), fontSize: 12),
          ),
        )
      else
        _LabelPicker(
          labels: filteredLabels,
          selected: _staticLabel,
          counts: _counts,
          target: kSamplesPerLabel,
          accentColor: kTeal,
          onSelect: (lbl) => setState(() { _staticLabel = lbl; _staticRecording = false; }),
        ),
      const SizedBox(height: 10),
      _SampleProgress(label: _staticLabel, count: count, target: kSamplesPerLabel, color: kTeal),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _BigBtn(
          label: '+ Capture',
          icon: Icons.camera_alt_outlined,
          accent: false, color: kTeal,
          enabled: _handLandmarks != null && !done,
          onTap: _captureStaticOnce,
        )),
        const SizedBox(width: 10),
        Expanded(child: _BigBtn(
          label: _staticRecording ? '⏹ Stop' : '⏺ Auto',
          icon: _staticRecording ? Icons.stop_circle_outlined : Icons.fiber_manual_record,
          accent: _staticRecording, color: kTeal,
          enabled: !done,
          onTap: () => setState(() => _staticRecording = !_staticRecording),
        )),
      ]),
      const SizedBox(height: 8),
      _BigBtn(
        label: 'Export CSV',
        icon: Icons.download_outlined,
        accent: false,
        color: kTeal,
        enabled: _staticCsvPath != null,
        onTap: _exportCurrentCsv,
      ),
      if (_staticCsvPath != null) ...[
        const SizedBox(height: 4),
        Text('→ $_staticCsvPath',
          style: const TextStyle(color: Color(0x33FFFFFF), fontSize: 10),
          maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    ]);
  }

  // ── Sequence panel ────────────────────────────────────────────────────────

  Widget _buildSequencePanel() {
    final count = _counts[_seqLabel] ?? 0;
    final done = count >= kSamplesPerLabel;
    return _BottomPanel(children: [
      _LabelPicker(
        labels: _dynamicLabels,
        selected: _seqLabel,
        counts: _counts,
        target: kSamplesPerLabel,
        accentColor: kOrange,
        onSelect: (lbl) => setState(() { _seqLabel = lbl; _seqRecording = false; _seqBuffer.clear(); }),
      ),
      const SizedBox(height: 10),
      _SampleProgress(label: _seqLabel, count: count, target: kSamplesPerLabel, color: kOrange),
      const SizedBox(height: 6),
      // Instruction text
      Text(
        _seqRecording
            ? 'Do the sign now — recording ${_seqBuffer.length}/$kSequenceFrames frames…'
            : 'Tap Record, then perform the sign once.',
        style: TextStyle(
          color: _seqRecording ? kOrange : const Color(0x66FFFFFF),
          fontSize: 12,
        ),
      ),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _BigBtn(
          label: _seqRecording ? '✕ Cancel' : '⏺ Record',
          icon: _seqRecording ? Icons.cancel_outlined : Icons.fiber_manual_record,
          accent: _seqRecording, color: kOrange,
          enabled: !done,
          onTap: _seqRecording ? _cancelSequence : _startSequence,
        )),
      ]),
      const SizedBox(height: 8),
      _BigBtn(
        label: 'Export CSV',
        icon: Icons.download_outlined,
        accent: false,
        color: kOrange,
        enabled: _seqCsvPath != null,
        onTap: _exportCurrentCsv,
      ),
      if (_seqCsvPath != null) ...[
        const SizedBox(height: 4),
        Text('→ $_seqCsvPath',
          style: const TextStyle(color: Color(0x33FFFFFF), fontSize: 10),
          maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    ]);
  }
}

// ─── Reusable widgets ─────────────────────────────────────────────────────────

class _BottomPanel extends StatelessWidget {
  final List<Widget> children;
  const _BottomPanel({required this.children});

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: Color(0xF00A0E1A),
      border: Border(top: BorderSide(color: Color(0x1AFFFFFF), width: 0.5)),
    ),
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: children),
  );
}

class _ModeTab extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  const _ModeTab({
    required this.label, required this.subtitle,
    required this.active, required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.12) : const Color(0x08FFFFFF),
          border: Border.all(color: active ? color.withValues(alpha: 0.5) : const Color(0x1AFFFFFF), width: active ? 1 : 0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(color: active ? color : const Color(0x88FFFFFF),
            fontSize: 12, fontWeight: FontWeight.w700)),
          Text(subtitle, style: const TextStyle(color: Color(0x44FFFFFF), fontSize: 10)),
        ]),
      ),
    ),
  );
}

class _LabelPicker extends StatelessWidget {
  final List<String> labels;
  final String selected;
  final Map<String, int> counts;
  final int target;
  final Color accentColor;
  final ValueChanged<String> onSelect;

  const _LabelPicker({
    required this.labels, required this.selected, required this.counts,
    required this.target, required this.accentColor, required this.onSelect,
  });

  @override
  Widget build(BuildContext context) => Row(children: [
    const Text('Label:', style: TextStyle(color: Color(0x66FFFFFF), fontSize: 12)),
    const SizedBox(width: 8),
    Expanded(child: SizedBox(height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: labels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final lbl = labels[i];
          final active = lbl == selected;
          final c = counts[lbl] ?? 0;
          final full = c >= target;
          return GestureDetector(
            onTap: () => onSelect(lbl),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: active ? accentColor.withValues(alpha: 0.2) : const Color(0x10FFFFFF),
                border: Border.all(
                  color: active ? accentColor.withValues(alpha: 0.5) : const Color(0x1AFFFFFF),
                  width: active ? 1 : 0.5,
                ),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(lbl, style: TextStyle(
                  color: active ? accentColor : full ? const Color(0x66FFFFFF) : const Color(0xB3FFFFFF),
                  fontSize: 12, fontWeight: active ? FontWeight.w700 : FontWeight.w400)),
                if (c > 0) ...[
                  const SizedBox(width: 4),
                  Text('$c', style: TextStyle(
                    color: full ? const Color(0x55FFFFFF) : accentColor,
                    fontSize: 10, fontWeight: FontWeight.w700)),
                ],
              ]),
            ),
          );
        },
      ),
    )),
  ]);
}

class _SampleProgress extends StatelessWidget {
  final String label;
  final int count;
  final int target;
  final Color color;

  const _SampleProgress({
    required this.label, required this.count,
    required this.target, required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final done = count >= target;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('"$label"', style: const TextStyle(
          color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(width: 6),
        Text('$count / $target', style: const TextStyle(
          color: Color(0x66FFFFFF), fontSize: 12)),
        if (done) ...[
          const SizedBox(width: 6),
          Text('✓', style: TextStyle(color: color, fontSize: 12)),
        ],
      ]),
      const SizedBox(height: 5),
      LayoutBuilder(builder: (ctx, c) => Container(
        height: 4, width: c.maxWidth,
        decoration: BoxDecoration(color: const Color(0x1AFFFFFF),
          borderRadius: BorderRadius.circular(2)),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: (count / target).clamp(0.0, 1.0),
          child: Container(decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(2))),
        ),
      )),
    ]);
  }
}

class _BigBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool accent;
  final Color color;
  final bool enabled;
  final VoidCallback? onTap;

  const _BigBtn({
    required this.label, required this.icon,
    required this.accent, required this.color,
    required this.enabled, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = enabled && onTap != null;
    return GestureDetector(
      onTap: active ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: accent ? color.withValues(alpha: 0.27) : active ? const Color(0x18FFFFFF) : const Color(0x0AFFFFFF),
          border: Border.all(
            color: accent ? color.withValues(alpha: 0.5) : active ? const Color(0x33FFFFFF) : const Color(0x1AFFFFFF),
            width: accent ? 1 : 0.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 16,
            color: accent ? color : active ? const Color(0xB3FFFFFF) : const Color(0x44FFFFFF)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(
            color: accent ? color : active ? const Color(0xB3FFFFFF) : const Color(0x44FFFFFF),
            fontSize: 13, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

class _SequenceRing extends StatelessWidget {
  final double progress;
  final int framesLeft;
  const _SequenceRing({required this.progress, required this.framesLeft});

  @override
  Widget build(BuildContext context) => Container(
    width: 120, height: 120,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: const Color(0xCC0A0E1A),
      border: Border.all(color: kOrange.withValues(alpha: 0.3), width: 2),
    ),
    child: Stack(alignment: Alignment.center, children: [
      SizedBox(width: 100, height: 100,
        child: CircularProgressIndicator(
          value: progress, color: kOrange,
          backgroundColor: kOrange.withValues(alpha: 0.15),
          strokeWidth: 6,
        )),
      Column(mainAxisSize: MainAxisSize.min, children: [
        Text('$framesLeft', style: const TextStyle(
          color: kOrange, fontSize: 28, fontWeight: FontWeight.w800)),
        const Text('frames', style: TextStyle(
          color: Color(0x88FFFFFF), fontSize: 11)),
      ]),
    ]),
  );
}

class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0)
      .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _anim,
    child: Container(width: 10, height: 10,
      decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle)),
  );
}
