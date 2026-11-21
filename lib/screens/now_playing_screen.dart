import 'package:flutter/material.dart';

import '../playback/playback.dart';
import '../widgets/artwork.dart';
import '../widgets/player_controls.dart';

class NowPlayingScreen extends StatelessWidget {
  const NowPlayingScreen(this.playback, {super.key});
  final Playback playback;

  String _time(Duration value) =>
      '${value.inMinutes}:${value.inSeconds.remainder(60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('In riproduzione')),
    body: CurrentItem(playback, (item) {
      if (item == null) {
        return const Center(child: Text('Nessun brano in riproduzione'));
      }
      return SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Artwork(
                  item.artUri,
                  size:
                      (MediaQuery.sizeOf(context).width - 48)
                          .clamp(0, 320)
                          .toDouble(),
                ),
                const SizedBox(height: 24),
                Text(
                  item.title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text(item.artist ?? '', textAlign: TextAlign.center),
                if (item.album?.isNotEmpty == true)
                  Text(item.album!, textAlign: TextAlign.center),
                StreamBuilder<Duration?>(
                  stream: playback.player.durationStream,
                  initialData: playback.player.duration,
                  builder: (_, durationSnapshot) {
                    final duration = durationSnapshot.data ?? Duration.zero;
                    return StreamBuilder<Duration>(
                      stream: playback.player.positionStream,
                      initialData: playback.player.position,
                      builder: (_, positionSnapshot) {
                        final ms = (positionSnapshot.data ?? Duration.zero)
                            .inMilliseconds
                            .clamp(0, duration.inMilliseconds);
                        return Column(
                          children: [
                            Slider(
                              max: duration.inMilliseconds.toDouble(),
                              value: ms.toDouble(),
                              onChanged:
                                  duration == Duration.zero
                                      ? null
                                      : (v) => playback.seek(
                                        Duration(milliseconds: v.round()),
                                      ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(_time(Duration(milliseconds: ms))),
                                Text(_time(duration)),
                              ],
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
                PlayerButtons(playback),
              ],
            ),
          ),
        ),
      );
    }),
  );
}
