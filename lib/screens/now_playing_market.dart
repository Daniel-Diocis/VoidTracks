import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'market_screen.dart';

class NowPlayingMarket extends StatefulWidget {
  final AudioPlayer player;
  final Map<String, dynamic> brano;
  final VoidCallback onNext;
  final VoidCallback onPrevious;

  const NowPlayingMarket({
    required this.player,
    required this.brano,
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
    final traccia = widget.brano;
    if (traccia == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(color: Colors.white),
      ),
      body: Center(
        child: Column(
          children: [
            SizedBox(height: 40),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.file(
                File(traccia['coverPath']),
                height: 300,
                width: 300,
                fit: BoxFit.cover,
              ),
            ),
            SizedBox(height: 30),
            Text(
              traccia['titolo'],
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            Text(
              traccia['artista'],
              style: TextStyle(color: Colors.white70, fontSize: 16),
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
        ),
      ),
    );
  }
} 
