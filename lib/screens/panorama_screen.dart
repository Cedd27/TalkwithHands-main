import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:panorama_viewer/panorama_viewer.dart';
import 'package:video_player/video_player.dart';

import '../models/panorama_scene.dart';
import '../services/api_config.dart';
import '../services/panorama_service.dart';
import '../services/video_player_service.dart';
import '../ui/app_shell.dart';
import '../utils/url_helper.dart';
import '../widgets/transparent_sign_video_overlay.dart';
import '../widgets/video_player_with_controls.dart';

class PanoramaScreen extends StatefulWidget {
  final String userName;
  const PanoramaScreen({super.key, required this.userName});

  @override
  State<PanoramaScreen> createState() => _PanoramaScreenState();
}

class _PanoramaScreenState extends State<PanoramaScreen> {
  // ── Cross-instance cache ─────────────────────────────────────────────
  // Navigator.push creates a BRAND NEW PanoramaScreen (and thus a brand
  // new State) every time the user opens "180 Pictures" from the menu,
  // even if they were just here before. This `static` field lives on the
  // class, not the State instance, so it survives that recreation: the
  // scene list is only fetched ONCE per app session. Every visit after
  // the first reuses it instantly instead of reloading.
  static List<PanoramaScene>? _cachedScenes;

  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late final PanoramaController _panoramaController;
  late Future<List<PanoramaScene>> _sceneFuture;
  List<PanoramaScene> _scenes = [];
  int _selectedIndex = 0;
  bool _viewerMode = false;

  // The panorama sphere is rendered natively (no WebView / JS engine to
  // spin up), so the only thing worth waiting on before showing it is the
  // equirectangular image itself. We precache it and show a small spinner
  // for that brief moment instead of a "Loading 180 pictures..." page.
  bool _panoramaLoading = false;

  String get _baseUrl {
    final baseUrl = ApiConfig.baseUrl;
    return baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
  }

  @override
  void initState() {
    super.initState();
    _panoramaController = PanoramaController();

    if (_cachedScenes != null) {
      // Already fetched during an earlier visit this session — resolve
      // instantly (no spinner).
      _scenes = _cachedScenes!;
      _sceneFuture = Future.value(_cachedScenes!);
    } else {
      _sceneFuture = _fetchScenes();
    }
  }

  // Wrapped so that ANY failure here — including a synchronous one thrown
  // by PanoramaService()'s constructor itself (e.g. missing base URL) —
  // becomes a normal Future error the FutureBuilder below can show as a
  // "Retry" screen, instead of an uncaught exception escaping initState
  // and taking the whole app down with it.
  Future<List<PanoramaScene>> _fetchScenes() async {
    try {
      return await PanoramaService().listPanoramaScenes();
    } catch (e) {
      throw Exception('Failed to load 180 pictures: $e');
    }
  }

  String _assetUrl(String assetPath) {
    final cleanPath = assetPath.split('/').map(Uri.encodeComponent).join('/');
    return '$_baseUrl/$cleanPath';
  }

  String _imageUrl(PanoramaScene scene) {
    if (scene.imageUrl.trim().isNotEmpty) {
      return getOptimizedUrl(scene.imageUrl, width: 1600);
    }
    return _assetUrl(scene.imageAsset);
  }

  // Equirectangular photos meant for 360°/180° viewing are often huge
  // (6000x3000+). Feeding that straight into a native GL texture (which is
  // what PanoramaViewer does via flutter_cube) can exceed the max texture
  // size on lower-end GPUs and crash the WHOLE app natively — not a
  // catchable Dart exception, just an instant exit. Capping the decoded
  // width here keeps every device safe while still looking sharp.
  static const int _maxPanoramaTextureWidth = 2048;

  ImageProvider _panoramaTextureProvider(PanoramaScene scene) {
    return ResizeImage(
      CachedNetworkImageProvider(_imageUrl(scene)),
      width: _maxPanoramaTextureWidth,
    );
  }

  bool _usesFlatPanorama(PanoramaScene scene) =>
      scene.id == 'classroom' || scene.id == 'school';

  Future<void> _loadPanorama(int index) async {
    if (index < 0 || index >= _scenes.length) return;
    if (!mounted) return;
    setState(() {
      _selectedIndex = index;
      _viewerMode = true;
      _panoramaLoading = true;
    });

    // Warm the image cache before swapping the sphere's texture so the
    // viewer doesn't pop in half-loaded. Flutter's own ImageCache means a
    // scene visited before this session resolves instantly here.
    try {
      await precacheImage(
        _panoramaTextureProvider(_scenes[index]),
        context,
      );
    } catch (_) {
      // Swallow — the panorama widget shows its own broken-image state.
    }

    if (!mounted) return;
    setState(() => _panoramaLoading = false);
  }

  // BENCH.jpg hotspot positions come from backend/data/panorama-scenes.json.
  // Keeping this as a direct pass-through avoids stale hard-coded overrides
  // pulling the marker back to the blue bench table.
  double _hotspotPitch(PanoramaScene scene, int i) => scene.hotspots[i].pitch;

  double _hotspotYaw(PanoramaScene scene, int i) => scene.hotspots[i].yaw;

  // ── Navigate panorama camera to a hotspot (no auto-play — user taps hotspot) ──
  void _navigateToHotspot(PanoramaHotspot hotspot) {
    final scene = _scenes[_selectedIndex];
    final i = scene.hotspots.indexOf(hotspot);
    if (i < 0) {
      _panoramaController.setView(hotspot.pitch, hotspot.yaw);
      return;
    }
    _panoramaController.setView(_hotspotPitch(scene, i), _hotspotYaw(scene, i));
  }

  void _showHotspotVideo(PanoramaHotspot hotspot) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => _PanoramaVideoDialog(
        title: hotspot.label,
        videoAsset: hotspot.videoAsset,
        videoUrl: hotspot.videoUrl,
      ),
    );
  }

  IconData _sceneIcon(PanoramaScene scene) {
    switch (scene.icon) {
      case 'bench':
        return Icons.chair_outlined;
      case 'school':
        return Icons.school_outlined;
      case 'classroom':
        return Icons.meeting_room_outlined;
      case 'crossing':
        return Icons.directions_walk_rounded;
      case 'cafe':
        return Icons.local_cafe_rounded;
      case 'route':
        return Icons.route_rounded;
      default:
        return Icons.threesixty_rounded;
    }
  }

  void _reload() {
    setState(() {
      _selectedIndex = 0;
      _viewerMode = false;
      _scenes = [];
      _panoramaLoading = false;
      // Retry/reload means the user explicitly wants fresh data — clear the
      // cache so this next fetch actually happens again.
      _cachedScenes = null;
      _sceneFuture = _fetchScenes();
    });
  }

  @override
  void dispose() {
    _panoramaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      endDrawer: AppMenuDrawer(
        userName: widget.userName,
        onClose: () => Navigator.of(context).pop(),
        activeScreen: '180 Pictures',
      ),
      body: AppBackground(
        imageAsset: 'assets/NEW BACKGROUND/new 180 pictures.png',
        child: Stack(
          children: [
            const Positioned.fill(
              child: IgnorePointer(
                child: _FloatingBubbles(),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  AppTopBar(
                    onBack: () {
                      if (_viewerMode) {
                        setState(() => _viewerMode = false);
                      } else {
                        Navigator.of(context).pop();
                      }
                    },
                    onMenu: () => _scaffoldKey.currentState?.openEndDrawer(),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 2, bottom: 12),
                    child: Text(
                      _viewerMode && _scenes.isNotEmpty
                          ? _scenes[_selectedIndex].title.toUpperCase()
                          : '180° PICTURES',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF1500C8),
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (!_viewerMode)
                    const SizedBox(
                      height: 120,
                      width: 240,
                      child: TransparentSignVideoOverlay(
                        videoAsset: 'assets/180.mp4',
                        fit: BoxFit.contain,
                        volume: 0,
                        threshold: 0.34,
                        smoothing: 0.08,
                      ),
                    ),
                  Expanded(
                    child: FutureBuilder<List<PanoramaScene>>(
                      future: _sceneFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child:
                                CircularProgressIndicator(color: Colors.white),
                          );
                        }

                        if (snapshot.hasError) {
                          return _ErrorState(
                            message:
                                'Cannot load 180 pictures. Make sure the backend is running.',
                            onRetry: _reload,
                          );
                        }

                        final scenes = snapshot.data ?? const [];
                        if (scenes.isEmpty) {
                          return _ErrorState(
                            message: 'No 180 pictures found.',
                            onRetry: _reload,
                          );
                        }

                        if (_scenes.isEmpty) {
                          _scenes = scenes;
                          _cachedScenes = scenes;
                        }

                        if (!_viewerMode) {
                          return _buildCategoryGrid();
                        }

                        return _buildViewer();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Category landing grid ───────────────────────────────────────────────
  Widget _buildCategoryGrid() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: GridView.builder(
        physics: const BouncingScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 0.92,
        ),
        itemCount: _scenes.length,
        itemBuilder: (context, index) {
          final scene = _scenes[index];
          return _PanoramaCategoryCard(
            title: scene.title,
            imageUrl: _imageUrl(scene),
            icon: _sceneIcon(scene),
            highlighted: index == 0,
            onView: () => _loadPanorama(index),
          );
        },
      ),
    );
  }

  // ── Words / hotspot list below the 180 viewer ───────────────────────────
  Widget _buildWordsList(List<PanoramaHotspot> hotspots) {
    if (hotspots.isEmpty) return const SizedBox.shrink();

    // Deduplicate by label, sorted alphabetically
    final seen = <String>{};
    final unique = hotspots
        .where((h) => seen.add(h.label.toLowerCase()))
        .toList()
      ..sort((a, b) => a.label.compareTo(b.label));

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Words',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF1500C8),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 4.5,
              mainAxisSpacing: 2,
              crossAxisSpacing: 4,
            ),
            itemCount: unique.length,
            itemBuilder: (context, i) {
              final hotspot = unique[i];
              final original = hotspots.firstWhere(
                (h) => h.label.toLowerCase() == hotspot.label.toLowerCase(),
              );
              return InkWell(
                onTap: () => _navigateToHotspot(original),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.play_circle_outline_rounded,
                        size: 16,
                        color: Color(0xFF0E7C8C),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          hotspot.label,
                          style: const TextStyle(
                            color: Color(0xFF0E3D44),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // Classroom and School are wide panorama strips, not equirectangular
  // sphere photos. Keep them flat so their original proportions stay intact.
  Widget _buildFlatPanorama(PanoramaScene scene) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.max(constraints.maxWidth, 1600.0);
        final aspectRatio = scene.id == 'classroom' ? 6.97 : 7.35;
        return InteractiveViewer(
          constrained: false,
          minScale: 1,
          maxScale: 4,
          boundaryMargin: const EdgeInsets.all(80),
          child: SizedBox(
            width: width,
            height: width / aspectRatio,
            child: Image(
              image: _panoramaTextureProvider(scene),
              fit: BoxFit.fill,
            ),
          ),
        );
      },
    );
  }

  // ── 180 viewer with hotspots + thumbnail strip ─────────────────────────
  Widget _buildViewer() {
    final scene = _scenes[_selectedIndex];
    final currentHotspots = scene.hotspots;

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                color: Colors.black,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_usesFlatPanorama(scene))
                      _buildFlatPanorama(scene)
                    else
                      PanoramaViewer(
                        key: ValueKey('panorama-${scene.id}'),
                        animSpeed: 0.0,
                        sensorControl: SensorControl.none,
                        panoramaController: _panoramaController,
                        hotspots: [
                          for (var i = 0; i < currentHotspots.length; i++)
                            Hotspot(
                              name: currentHotspots[i].id,
                              latitude: _hotspotPitch(scene, i),
                              longitude: _hotspotYaw(scene, i),
                              width: 46 *
                                  (currentHotspots[i].size <= 0
                                      ? 1
                                      : currentHotspots[i].size),
                              height: 46 *
                                  (currentHotspots[i].size <= 0
                                      ? 1
                                      : currentHotspots[i].size),
                              widget: _HotspotMarker(
                                onTap: () =>
                                    _showHotspotVideo(currentHotspots[i]),
                              ),
                            ),
                        ],
                        child: Image(
                          image: _panoramaTextureProvider(scene),
                        ),
                      ),
                    if (!_panoramaLoading)
                      _DragHint(key: ValueKey('hint-${scene.id}')),
                    if (_panoramaLoading)
                      Container(
                        color: Colors.black54,
                        alignment: Alignment.center,
                        child: const CircularProgressIndicator(
                          color: Colors.white,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        _buildWordsList(currentHotspots),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ── Round play-button hotspot marker placed on the sphere ──────────────────
class _HotspotMarker extends StatelessWidget {
  final VoidCallback onTap;

  const _HotspotMarker({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.22),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.9),
            width: 2.4,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.play_arrow_rounded,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }
}

// ── "Drag to look around" hint that fades out, same as the old JS one ──────
class _DragHint extends StatefulWidget {
  const _DragHint({super.key});

  @override
  State<_DragHint> createState() => _DragHintState();
}

class _DragHintState extends State<_DragHint> {
  bool _visible = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: AnimatedOpacity(
            opacity: _visible ? 1 : 0,
            duration: const Duration(milliseconds: 900),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.66),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'Drag to look around',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PanoramaVideoDialog extends StatefulWidget {
  final String title;
  final String videoAsset;
  final String videoUrl;

  const _PanoramaVideoDialog({
    required this.title,
    required this.videoAsset,
    required this.videoUrl,
  });

  @override
  State<_PanoramaVideoDialog> createState() => _PanoramaVideoDialogState();
}

class _PanoramaVideoDialogState extends State<_PanoramaVideoDialog> {
  VideoPlayerController? _controller;
  String? _error;
  bool _isFullscreen = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final controller = await VideoPlayerService.createController(
        sources: VideoPlayerService.buildSources(
          videoUrl: widget.videoUrl,
          videoAsset: widget.videoAsset,
        ),
        playbackSpeed: 1.0,
      );

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        _error = null;
      });
    } on VideoLoadException catch (_) {
      if (!mounted) return;
      setState(() {
        _error =
            'Cannot play this hotspot video.\nPlease restart the backend and try again.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Cannot play this hotspot video.';
      });
    }
  }

  Future<void> _toggleFullscreen() async {
    if (_isFullscreen) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } else {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
    setState(() => _isFullscreen = !_isFullscreen);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: _isFullscreen
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
      child: Container(
        width: _isFullscreen ? double.infinity : 620,
        height: _isFullscreen ? double.infinity : null,
        color: Colors.black,
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisSize:
                      _isFullscreen ? MainAxisSize.max : MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (!_isFullscreen)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 16, 56, 8),
                        child: Text(
                          widget.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    if (controller == null)
                      AspectRatio(
                        aspectRatio: 16 / 9,
                        child: _buildVideoBody(null),
                      )
                    else
                      VideoPlayerWithControls(
                        controller: controller,
                        initialSpeed: 1.0,
                        video: _buildVideoBody(controller),
                        additionalControls: IconButton(
                          color: Colors.white,
                          onPressed: _toggleFullscreen,
                          icon: Icon(
                            _isFullscreen
                                ? Icons.fullscreen_exit_rounded
                                : Icons.fullscreen_rounded,
                          ),
                          tooltip:
                              _isFullscreen ? 'Exit Fullscreen' : 'Fullscreen',
                        ),
                      ),
                  ],
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Material(
                  color: const Color(0xFFFF2F2F),
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    child: const SizedBox(
                      width: 34,
                      height: 34,
                      child: Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
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

  Widget _buildVideoBody(VideoPlayerController? controller) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    if (controller == null) {
      return const Center(
        child: CircularProgressIndicator(color: kAccent),
      );
    }

    return VideoPlayer(controller);
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF050505),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              Material(
                color: kAccent,
                borderRadius: BorderRadius.circular(999),
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: onRetry,
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    alignment: Alignment.center,
                    child: const Text(
                      'Retry',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
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

// ── Category card (Image + title bar + View button) ────────────────────────
class _PanoramaCategoryCard extends StatelessWidget {
  final String title;
  final String imageUrl;
  final bool highlighted;
  final VoidCallback onView;
  final IconData icon;

  const _PanoramaCategoryCard({
    required this.title,
    required this.imageUrl,
    required this.onView,
    required this.icon,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onView,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF11919C), Color(0xFF0A5C68)],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: highlighted ? kAccent : const Color(0xFFAEEAF2),
            width: highlighted ? 2.6 : 1.6,
          ),
          boxShadow: [
            BoxShadow(
              color: (highlighted ? kAccent : Colors.black)
                  .withValues(alpha: highlighted ? 0.4 : 0.18),
              blurRadius: highlighted ? 18 : 10,
              spreadRadius: highlighted ? 1 : 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Backing color shows briefly while the crop loads.
                  Container(color: const Color(0xFF08414A)),
                  // Fills the whole card — a portion of the photo gets
                  // cropped off (top/bottom or sides) instead of
                  // letterboxing, so the card never shows empty bars.
                  Positioned.fill(
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                      // Thumbnails only need to be a few hundred px wide,
                      // not the full panorama resolution — this caps how
                      // large a bitmap gets decoded/cached per card.
                      memCacheWidth: 480,
                      fadeInDuration: const Duration(milliseconds: 150),
                      errorWidget: (_, __, ___) => Container(
                        color: const Color(0xFF08414A),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.threesixty_rounded,
                          color: kAccent.withValues(alpha: 0.8),
                          size: 36,
                        ),
                      ),
                      placeholder: (_, __) => Container(
                        color: const Color(0xFF08414A),
                        alignment: Alignment.center,
                        child: const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: kAccent,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Category icon badge
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [kAccent, Color(0xFF1387C9)],
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.85),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: kAccent.withValues(alpha: 0.6),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Icon(icon, color: Colors.white, size: 14),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF0E7C8C), Color(0xFF0A5C68)],
                ),
              ),
              child: Column(
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                    child: InkWell(
                      onTap: onView,
                      borderRadius: BorderRadius.circular(999),
                      child: Ink(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF3EDB7A), Color(0xFF23A147)],
                          ),
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF34C759)
                                  .withValues(alpha: 0.55),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Container(
                          width: 96,
                          height: 30,
                          alignment: Alignment.center,
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.play_arrow_rounded,
                                  color: Colors.white, size: 15),
                              SizedBox(width: 3),
                              Text(
                                'View',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Decorative floating bubbles for the background ──────────────────────────
// Purely visual, non-interactive layer — sits behind all existing screen
// content and does not change any other part of the design.
const List<Color> _bubbleColors = [
  Color(0xFF1500C8),
  kAccent,
  Color(0xFF34C759),
  Color(0xFF0B8FFF),
  Color(0xFF9C27B0),
];

class _BubbleSpec {
  final double dx; // horizontal anchor, 0..1 fraction of width
  final double size;
  final double speed; // relative rise speed
  final double phase; // 0..1 start offset so bubbles don't move in sync
  final double wobble; // horizontal sway amount in logical pixels
  final Color color;
  final bool outline; // some bubbles are soft rings instead of filled dots

  const _BubbleSpec({
    required this.dx,
    required this.size,
    required this.speed,
    required this.phase,
    required this.wobble,
    required this.color,
    required this.outline,
  });
}

class _FloatingBubbles extends StatefulWidget {
  const _FloatingBubbles();

  @override
  State<_FloatingBubbles> createState() => _FloatingBubblesState();
}

class _FloatingBubblesState extends State<_FloatingBubbles>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_BubbleSpec> _bubbles;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 28),
    )..repeat();

    // Fixed seed so the layout is stable across rebuilds/hot reloads
    // instead of jumping to a new random arrangement every time.
    final rnd = math.Random(7);
    _bubbles = List.generate(16, (i) {
      final color = _bubbleColors[rnd.nextInt(_bubbleColors.length)];
      return _BubbleSpec(
        dx: rnd.nextDouble(),
        size: 14 + rnd.nextDouble() * 46,
        speed: 0.45 + rnd.nextDouble() * 0.85,
        phase: rnd.nextDouble(),
        wobble: 8 + rnd.nextDouble() * 18,
        color: color,
        outline: rnd.nextDouble() < 0.4,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final canvasSize = constraints.biggest;
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return CustomPaint(
              size: canvasSize,
              painter: _BubblesPainter(
                bubbles: _bubbles,
                progress: _controller.value,
              ),
            );
          },
        );
      },
    );
  }
}

class _BubblesPainter extends CustomPainter {
  final List<_BubbleSpec> bubbles;
  final double progress;

  _BubblesPainter({required this.bubbles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    for (final b in bubbles) {
      // t travels 0 -> 1 -> 0 (loops) at each bubble's own speed/offset.
      final t = (progress * b.speed + b.phase) % 1.0;
      final y = size.height * (1 - t);
      final wobbleX = math.sin((t * 2 * math.pi) + b.phase * 10) * b.wobble;
      final x = size.width * b.dx + wobbleX;
      final radius = b.size / 2;

      // Fades in near the bottom, fades out near the top so bubbles never
      // pop in/out abruptly.
      final envelope = math.sin(math.pi * t).clamp(0.0, 1.0);
      final opacity = 0.08 + 0.16 * envelope;

      if (b.outline) {
        final ring = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = b.color.withValues(alpha: opacity * 1.6);
        canvas.drawCircle(Offset(x, y), radius, ring);
      } else {
        final fill = Paint()
          ..style = PaintingStyle.fill
          ..color = b.color.withValues(alpha: opacity);
        canvas.drawCircle(Offset(x, y), radius, fill);
      }

      // Tiny glossy highlight so bubbles read as bubbles, not flat dots.
      final highlight = Paint()
        ..style = PaintingStyle.fill
        ..color = Colors.white.withValues(alpha: opacity * 1.4);
      canvas.drawCircle(
        Offset(x - radius * 0.32, y - radius * 0.32),
        radius * 0.22,
        highlight,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BubblesPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
