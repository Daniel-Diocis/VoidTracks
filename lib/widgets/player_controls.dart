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
  const PlayerButtons(this.playback, {super.key, this.compact = false});
  final Playback playback;
  final bool compact;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (!compact)
        IconButton(
          tooltip: 'Precedente',
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
  Widget build(BuildContext context) => CurrentItem(
    playback,
    (item) =>
        item == null
            ? const SizedBox.shrink()
            : ListTile(
              onTap: onOpen,
              leading: Artwork(item.artUri),
              title: Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                item.artist ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: PlayerButtons(playback, compact: true),
            ),
  );
}
