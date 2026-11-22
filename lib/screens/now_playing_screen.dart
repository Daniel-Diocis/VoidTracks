import 'dart:math' as math;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../playback/playback.dart';
import '../widgets/artwork.dart';
import '../widgets/cover_color.dart';
import '../widgets/player_controls.dart';

class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen._(this.playback, this.onSongMenu);
  final ValueChanged<String>? onSongMenu;
  final Playback playback;

  static Future<void> show(
    BuildContext context,
    Playback playback, {
    ValueChanged<String>? onSongMenu,
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    enableDrag: false,
    constraints: const BoxConstraints(maxWidth: double.infinity),
    backgroundColor: Colors.transparent,
    showDragHandle: false,
    builder:
        (context) => MediaQuery.fromView(
          view: View.of(context),
          child: NowPlayingScreen._(playback, onSongMenu),
        ),
  );

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
  final _scroll = ScrollController();
  Offset _start = Offset.zero;
  int? _pointer;

  void _startSwipe(PointerDownEvent event) {
    if (_pointer != null ||
        (_scroll.hasClients && _scroll.position.extentBefore > 0)) {
      return;
    }
    _pointer = event.pointer;
    _start = event.position;
  }

  void _updateSwipe(PointerMoveEvent event) {
    if (event.pointer != _pointer) return;
    final delta = event.position - _start;
    if (delta.distance < kTouchSlop) return;
    if (delta.dy <= delta.dx.abs()) {
      _pointer = null;
    } else if (delta.dy >= 48) {
      _pointer = null;
      if (ModalRoute.of(context)?.isCurrent == true) Navigator.pop(context);
    }
  }

  void _endSwipe(PointerEvent event) {
    if (_pointer == event.pointer) _pointer = null;
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.opaque,
    onPointerDown: _startSwipe,
    onPointerMove: _updateSwipe,
    onPointerUp: _endSwipe,
    onPointerCancel: _endSwipe,
    child: CurrentItem(widget.playback, (item) {
      if (item == null) {
        return Scaffold(
          appBar: AppBar(leading: const _CollapseButton()),
          body: const Center(child: Text('Nessun brano in riproduzione')),
        );
      }
      return _TrackView(
        key: ValueKey(item.artUri),
        item: item,
        playback: widget.playback,
        scrollController: _scroll,
        onSongMenu: widget.onSongMenu,
      );
    }),
  );
}

class _CollapseButton extends StatelessWidget {
  const _CollapseButton();

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Riduci player',
    icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
    onPressed: () => Navigator.pop(context),
  );
}

class _TrackView extends StatefulWidget {
  const _TrackView({
    super.key,
    required this.item,
    required this.playback,
    required this.scrollController,
    required this.onSongMenu,
  });
  final MediaItem item;
  final ScrollController scrollController;
  final ValueChanged<String>? onSongMenu;
  final Playback playback;

  @override
  State<_TrackView> createState() => _TrackViewState();
}

class _TrackViewState extends State<_TrackView> {
  late final _color = coverColor(Artwork.providerFor(widget.item.artUri));

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Color>(
      future: _color,
      builder: (_, snapshot) {
        final background = snapshot.data ?? playerFallbackColor;
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [background, Color.lerp(background, Colors.black, .55)!],
            ),
          ),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              leading: const _CollapseButton(),
              title: const Text('In riproduzione'),
              centerTitle: true,
              actions: [
                if (widget.onSongMenu != null)
                  IconButton(
                    tooltip: 'Opzioni brano',
                    icon: const Icon(Icons.more_vert),
                    onPressed: () => widget.onSongMenu!(widget.item.id),
                  ),
              ],
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              elevation: 0,
              scrolledUnderElevation: 0,
              systemOverlayStyle: SystemUiOverlayStyle.light,
            ),
            body: SafeArea(top: false, child: LayoutBuilder(builder: _content)),
          ),
        );
      },
    );
  }

  Widget _content(BuildContext context, BoxConstraints space) {
    final width = math.min(480.0, math.max(0.0, space.maxWidth - 48));
    final wide = space.maxWidth >= 680 && space.maxWidth > space.maxHeight;
    final coverSize =
        wide
            ? math.min(
              420.0,
              math.min(space.maxWidth * .42, space.maxHeight * .80),
            )
            : math.min(width, math.max(170.0, space.maxHeight * .56));
    final cover = Artwork(widget.item.artUri, size: coverSize);
    final controls = _controls(context);
    return SingleChildScrollView(
      controller: widget.scrollController,
      physics: const ClampingScrollPhysics(),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: space.maxHeight),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
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
                        children: [cover, const SizedBox(height: 22), controls],
                      ),
                    ),
          ),
        ),
      ),
    );
  }

  Widget _controls(BuildContext context) {
    final item = widget.item;
    final text = Theme.of(context).textTheme;
    return Column(
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
            style: IconButton.styleFrom(foregroundColor: Colors.white),
          ),
          child: PlayerButtons(widget.playback, expanded: true),
        ),
      ],
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
