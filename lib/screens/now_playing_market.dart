import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class NowPlayingMarket extends StatefulWidget {
  final AudioPlayer player;
  final ValueNotifier<Map<String, dynamic>?> currentTrackNotifier;
  final VoidCallback onNext;
  final VoidCallback onPrevious;

  const NowPlayingMarket({
    required this.player,
    required this.currentTrackNotifier,
    required this.onNext,
    required this.onPrevious,
    Key? key,
  }) : super(key: key);

  @override
  _NowPlayingMarketState createState() => _NowPlayingMarketState();
}

class _NowPlayingMarketState extends State<NowPlayingMarket> {
  @override
  void initState() {
    super.initState();
    // Aggiorna la UI quando cambia lo stato del player
    widget.player.playerStateStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return "${twoDigits(d.inMinutes.remainder(60))}:${twoDigits(d.inSeconds.remainder(60))}";
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, dynamic>?>(
      valueListenable: widget.currentTrackNotifier,
      builder: (context, traccia, _) {
        if (traccia == null) return const SizedBox.shrink(); // Nessun brano selezionato

        final screenWidth = MediaQuery.of(context).size.width;

        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: BackButton(color: Colors.white),
          ),
          body: Stack(
            fit: StackFit.expand,
            children: [
              // 📸 Sfondo sfocato con la cover
              if (traccia['cover_path'] != null)
                Positioned.fill(
                  child: Image.file(
                    File(traccia['cover_path']),
                    fit: BoxFit.cover,
                  ),
                ),
              if (traccia['cover_path'] != null)
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30), // 🌫️ Sfoca molto
                    child: Container(
                      color: Colors.black.withOpacity(0.4), // 🖤 Sovrappone una tinta nera trasparente
                    ),
                  ),
                ),

              // 🧱 Contenuti in primo piano
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // 🎵 Copertina
                            Container(
                              height: MediaQuery.of(context).size.width * 0.9,
                              width: MediaQuery.of(context).size.width * 0.9,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.4),
                                    blurRadius: 60,
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: Image.file(
                                  File(traccia['cover_path']),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              traccia['titolo'],
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              traccia['artista'],
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 18,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              traccia['album'],
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 14,
                                fontStyle: FontStyle.italic,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),

                      // 🎚️ Seekbar
                      StreamBuilder<Duration?>(
                        stream: widget.player.durationStream,
                        builder: (context, snapshot) {
                          final duration = snapshot.data ?? Duration.zero;
                          return StreamBuilder<Duration>(
                            stream: widget.player.positionStream,
                            builder: (context, snapshot) {
                              final position = snapshot.data ?? Duration.zero;
                              return Column(
                                children: [
                                  Slider(
                                    min: 0,
                                    max: duration.inMilliseconds.toDouble(),
                                    value: position.inMilliseconds.clamp(0, duration.inMilliseconds).toDouble(),
                                    onChanged: (value) {
                                      widget.player.seek(Duration(milliseconds: value.toInt()));
                                    },
                                    activeColor: Colors.white,
                                    inactiveColor: Colors.grey,
                                  ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(_formatDuration(position), style: TextStyle(color: Colors.white)),
                                      Text(_formatDuration(duration), style: TextStyle(color: Colors.white)),
                                    ],
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),

                      const SizedBox(height: 20),

                      // 🎛️ Controlli
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.skip_previous, color: Colors.white),
                            iconSize: 50,
                            onPressed: widget.onPrevious,
                          ),
                          const SizedBox(width: 20),
                          IconButton(
                            icon: Icon(
                              widget.player.playing ? Icons.pause_circle_filled : Icons.play_circle_filled,
                              color: Colors.white,
                            ),
                            iconSize: 75,
                            onPressed: () {
                              if (widget.player.playing) {
                                widget.player.pause();
                              } else {
                                widget.player.play();
                              }
                            },
                          ),
                          const SizedBox(width: 20),
                          IconButton(
                            icon: const Icon(Icons.skip_next, color: Colors.white),
                            iconSize: 50,
                            onPressed: widget.onNext,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
} 
