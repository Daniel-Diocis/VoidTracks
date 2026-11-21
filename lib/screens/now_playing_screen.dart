import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../playback/playback.dart';
import '../widgets/artwork.dart';
import '../widgets/cover_color.dart';
import '../widgets/player_controls.dart';

class NowPlayingScreen extends StatelessWidget {
  const NowPlayingScreen(this.playback, {super.key});
  final Playback playback;

  @override
  Widget build(BuildContext context) => CurrentItem(playback, (item) {
    if (item == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Nessun brano in riproduzione')),
      );
    }
    return _TrackView(
      key: ValueKey(item.artUri),
      item: item,
      playback: playback,
    );
  });
}

class _TrackView extends StatefulWidget {
  const _TrackView({super.key, required this.item, required this.playback});
  final MediaItem item;
  final Playback playback;

  @override
  State<_TrackView> createState() => _TrackViewState();
}

class _TrackViewState extends State<_TrackView> {
  late final _color = coverColor(Artwork.providerFor(widget.item.artUri));

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final item = widget.item;
    return FutureBuilder<Color>(
      future: _color,
      builder: (_, snapshot) {
        final background = snapshot.data ?? playerFallbackColor;
        return Scaffold(
          backgroundColor: background,
          appBar: AppBar(
            title: const Text('In riproduzione'),
            centerTitle: true,
            backgroundColor: background,
            foregroundColor: Colors.white,
            elevation: 0,
            scrolledUnderElevation: 0,
            systemOverlayStyle: SystemUiOverlayStyle.light,
          ),
          body: SafeArea(
            top: false,
            child: LayoutBuilder(
              builder: (_, space) {
                final width = math.min(
                  480.0,
                  math.max(0.0, space.maxWidth - 48),
                );
                final wide =
                    space.maxWidth >= 680 && space.maxWidth > space.maxHeight;
                final coverSize =
                    wide
                        ? math.min(
                          420.0,
                          math.min(space.maxWidth * .42, space.maxHeight * .80),
                        )
                        : math.min(
                          width,
                          math.max(170.0, space.maxHeight * .56),
                        );
                final cover = Artwork(item.artUri, size: coverSize);
                final controls = Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.title,
                      textAlign: TextAlign.center,
                      style: text.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (item.artist?.isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.artist!,
                        textAlign: TextAlign.center,
                        style: text.titleMedium?.copyWith(color: Colors.white),
                      ),
                    ],
                    if (item.album?.isNotEmpty == true) ...[
                      const SizedBox(height: 3),
                      Text(
                        item.album!,
                        textAlign: TextAlign.center,
                        style: text.bodyMedium?.copyWith(
                          color: Colors.white70,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    _Progress(widget.playback),
                    const SizedBox(height: 12),
                    IconButtonTheme(
                      data: IconButtonThemeData(
                        style: IconButton.styleFrom(
                          foregroundColor: Colors.white,
                        ),
                      ),
                      child: PlayerButtons(widget.playback, expanded: true),
                    ),
                  ],
                );
                return Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 18,
                    ),
                    child:
                        wide
                            ? ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 940),
                              child: Row(
                                children: [
                                  cover,
                                  const SizedBox(width: 32),
                                  Expanded(child: controls),
                                ],
                              ),
                            )
                            : SizedBox(
                              width: width,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  cover,
                                  const SizedBox(height: 22),
                                  controls,
                                ],
                              ),
                            ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress(this.playback);
  final Playback playback;

  String _time(Duration value) =>
      '${value.inMinutes}:${value.inSeconds.remainder(60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) => StreamBuilder<Duration?>(
    stream: playback.player.durationStream,
    initialData: playback.player.duration,
    builder: (_, total) {
      final duration = total.data ?? Duration.zero;
      return StreamBuilder<Duration>(
        stream: playback.player.positionStream,
        initialData: playback.player.position,
        builder: (_, elapsed) {
          final ms = (elapsed.data ?? Duration.zero).inMilliseconds.clamp(
            0,
            duration.inMilliseconds,
          );
          return Column(
            children: [
              Slider(
                max: duration.inMilliseconds.toDouble(),
                value: ms.toDouble(),
                activeColor: Colors.white,
                inactiveColor: Colors.white30,
                onChanged:
                    duration == Duration.zero
                        ? null
                        : (v) =>
                            playback.seek(Duration(milliseconds: v.round())),
              ),
              DefaultTextStyle(
                style: Theme.of(
                  context,
                ).textTheme.labelMedium!.copyWith(color: Colors.white),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_time(Duration(milliseconds: ms))),
                    Text(_time(duration)),
                  ],
                ),
              ),
            ],
          );
        },
      );
    },
  );
}
