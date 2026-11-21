import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../playback/playback.dart';
import 'artwork.dart';

class CurrentItem extends StatelessWidget {
  const CurrentItem(this.playback, this.builder, {super.key});
  final Playback playback;
  final Widget Function(MediaItem?) builder;

  @override
  Widget build(BuildContext context) => StreamBuilder<SequenceState?>(
    stream: playback.player.sequenceStateStream,
    initialData: playback.player.sequenceState,
    builder:
        (_, snapshot) =>
            builder(snapshot.data?.currentSource?.tag as MediaItem?),
  );
}

class PlayerButtons extends StatelessWidget {
  const PlayerButtons(this.playback, {super.key});
  final Playback playback;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        tooltip: 'Ricomincia o torna al brano precedente',
        icon: const Icon(Icons.skip_previous),
        onPressed: playback.previous,
      ),
      StreamBuilder<bool>(
        stream: playback.player.playingStream,
        initialData: playback.player.playing,
        builder:
            (_, state) => IconButton(
              tooltip: state.data == true ? 'Pausa' : 'Riproduci',
              icon: Icon(state.data == true ? Icons.pause : Icons.play_arrow),
              onPressed: playback.toggle,
            ),
      ),
      IconButton(
        tooltip: 'Successivo',
        icon: const Icon(Icons.skip_next),
        onPressed: playback.next,
      ),
    ],
  );
}

class MiniPlayer extends StatelessWidget {
  const MiniPlayer(this.playback, {super.key, required this.onOpen});
  final Playback playback;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return CurrentItem(playback, (item) {
      if (item == null) return const SizedBox.shrink();
      return SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Material(
            color: colors.inverseSurface,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              contentPadding: const EdgeInsetsDirectional.only(
                start: 12,
                end: 4,
              ),
              horizontalTitleGap: 10,
              textColor: colors.onInverseSurface,
              onTap: onOpen,
              leading: Artwork(item.artUri),
              title: Text(
                item.title,
                style: const TextStyle(fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                item.artist ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: IconButtonTheme(
                data: IconButtonThemeData(
                  style: IconButton.styleFrom(
                    foregroundColor: colors.onInverseSurface,
                  ),
                ),
                child: PlayerButtons(playback),
              ),
            ),
          ),
        ),
      );
    });
  }
}
