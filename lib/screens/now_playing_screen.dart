import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../models/track.dart';

class NowPlayingScreen extends StatefulWidget {
  final AudioPlayer player;
  final ValueNotifier<Track?> currentTrackNotifier;
  final VoidCallback onNext;
  final VoidCallback onPrevious;

  const NowPlayingScreen({
    required this.player,
    required this.currentTrackNotifier,
    required this.onNext,
    required this.onPrevious,
    Key? key,
  }) : super(key: key);

  @override
  _NowPlayingScreenState createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
  @override
  void initState() {
    super.initState();

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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(color: Colors.white),
      ),
      body: ValueListenableBuilder<Track?>(
        valueListenable: widget.currentTrackNotifier,
        builder: (context, track, _) {
          if (track == null) {
            return Center(
              child: Text(
                '⛔ Nessun brano in riproduzione',
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          return Column(
            children: [
              SizedBox(height: 40),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.file(
                  File(track.cover_path),
                  height: 300,
                  width: 300,
                  fit: BoxFit.cover,
                ),
              ),
              SizedBox(height: 30),
              Text(
                  track.titolo,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 10),
                Text(
                  track.artista,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 18,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 6),
                Text(
                  track.album,
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              SizedBox(height: 10),
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
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(_formatDuration(position), style: TextStyle(color: Colors.white)),
                                Text(_formatDuration(duration), style: TextStyle(color: Colors.white)),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
              SizedBox(height: 30),
              StreamBuilder<PlayerState>(
                stream: widget.player.playerStateStream,
                builder: (context, snapshot) {
                  final playing = snapshot.data?.playing ?? false;

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: Icon(Icons.skip_previous, color: Colors.white),
                        iconSize: 40,
                        onPressed: widget.onPrevious,
                      ),
                      IconButton(
                        icon: Icon(playing ? Icons.pause_circle : Icons.play_circle, color: Colors.white),
                        iconSize: 60,
                        onPressed: () {
                          if (playing) {
                            widget.player.pause();
                          } else {
                            widget.player.play();
                          }
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.skip_next, color: Colors.white),
                        iconSize: 40,
                        onPressed: widget.onNext,
                      ),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}