import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoPlayerWithControls extends StatefulWidget {
  final VideoPlayerController controller;
  final Widget? video;
  final double? aspectRatio;
  final Color accentColor;
  final double initialSpeed;
  final Widget? additionalControls;
  final Widget? belowControls;

  const VideoPlayerWithControls({
    super.key,
    required this.controller,
    this.video,
    this.aspectRatio,
    this.accentColor = const Color(0xFFFF9800),
    this.initialSpeed = 1.0,
    this.additionalControls,
    this.belowControls,
  });

  @override
  State<VideoPlayerWithControls> createState() =>
      _VideoPlayerWithControlsState();
}

class _VideoPlayerWithControlsState extends State<VideoPlayerWithControls> {
  static const _speeds = [0.5, 0.75, 1.0, 1.5, 2.0];
  late double _selectedSpeed;

  @override
  void initState() {
    super.initState();
    _selectedSpeed = widget.initialSpeed;
  }

  @override
  void didUpdateWidget(covariant VideoPlayerWithControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _selectedSpeed = widget.initialSpeed;
      if (widget.controller.value.isInitialized) {
        unawaited(widget.controller.setPlaybackSpeed(widget.initialSpeed));
      }
    }
  }

  Future<void> _togglePlayback(bool isPlaying) async {
    if (isPlaying) {
      await widget.controller.pause();
    } else {
      await widget.controller.play();
    }
  }

  Future<void> _replay() async {
    await widget.controller.seekTo(Duration.zero);
    await widget.controller.play();
  }

  Future<void> _selectSpeed(double speed) async {
    setState(() => _selectedSpeed = speed);
    await widget.controller.setPlaybackSpeed(speed);
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final value = controller.value;
    if (!value.isInitialized) return const SizedBox.shrink();

    final aspectRatio = widget.aspectRatio ?? value.aspectRatio;
    return LayoutBuilder(
      builder: (context, constraints) {
        final controlsHeight = 220.0 +
            (widget.additionalControls == null ? 0 : 48) +
            (widget.belowControls == null ? 0 : 24);
        final maxVideoHeight = constraints.maxHeight.isFinite
            ? (constraints.maxHeight - controlsHeight)
                .clamp(80.0, double.infinity)
            : double.infinity;
        final videoAspectRatio =
            maxVideoHeight.isFinite && constraints.maxWidth.isFinite
                ? (aspectRatio > 0 ? aspectRatio : 16 / 9)
                    .clamp(
                      constraints.maxWidth / maxVideoHeight,
                      double.infinity,
                    )
                    .toDouble()
                : (aspectRatio > 0 ? aspectRatio : 16 / 9);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: videoAspectRatio,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: ColoredBox(
                  color: Colors.black,
                  child: widget.video ?? VideoPlayer(controller),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              decoration: BoxDecoration(
                color: const Color(0xFF102B54),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                    color: widget.accentColor.withValues(alpha: 0.6)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  VideoProgressIndicator(
                    controller,
                    allowScrubbing: true,
                    colors: VideoProgressColors(
                      playedColor: widget.accentColor,
                      bufferedColor: Colors.white54,
                      backgroundColor: Colors.white24,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ValueListenableBuilder<VideoPlayerValue>(
                    valueListenable: controller,
                    builder: (context, playback, _) {
                      final finished = playback.isCompleted;
                      final playbackButton = _PlaybackButton(
                        icon: playback.isPlaying
                            ? Icons.pause_rounded
                            : finished
                                ? Icons.replay_rounded
                                : Icons.play_arrow_rounded,
                        label: playback.isPlaying
                            ? 'Pause'
                            : finished
                                ? 'Replay'
                                : 'Play',
                        color: const Color(0xFF1687D9),
                        onPressed: finished
                            ? _replay
                            : () => _togglePlayback(playback.isPlaying),
                      );
                      if (widget.additionalControls == null) {
                        return SizedBox(
                          width: double.infinity,
                          child: playbackButton,
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: playbackButton),
                          const SizedBox(width: 8),
                          widget.additionalControls!,
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  if (widget.belowControls != null) widget.belowControls!,
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 48,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _speeds.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final speed = _speeds[index];
                        final selected = speed == _selectedSpeed;
                        return SizedBox(
                          width: 58,
                          child: Material(
                            color: selected
                                ? widget.accentColor
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () => _selectSpeed(speed),
                              child: Container(
                                constraints: const BoxConstraints(
                                  minWidth: 48,
                                  minHeight: 48,
                                ),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: selected
                                        ? widget.accentColor
                                        : Colors.white54,
                                    width: 1.5,
                                  ),
                                ),
                                child: Text(
                                  '${speed}x',
                                  style: TextStyle(
                                    color:
                                        selected ? Colors.black : Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PlaybackButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Future<void> Function() onPressed;

  const _PlaybackButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 24),
        label: Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}
