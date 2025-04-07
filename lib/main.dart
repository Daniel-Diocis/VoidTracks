import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: MusicPlayer(),
    );
  }
}

class MusicPlayer extends StatefulWidget {
  @override
  _MusicPlayerState createState() => _MusicPlayerState();
}

class _MusicPlayerState extends State<MusicPlayer> {
  late AudioPlayer _player;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();

    // Puoi caricare un file remoto oppure locale
    _player.setUrl(
      "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3",
    );
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Lettore musicale")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            StreamBuilder<PlayerState>(
              stream: _player.playerStateStream,
              builder: (context, snapshot) {
                final playerState = snapshot.data;
                final playing = playerState?.playing;
                final processingState = playerState?.processingState;

                if (processingState == ProcessingState.loading ||
                    processingState == ProcessingState.buffering) {
                  return CircularProgressIndicator();
                } else if (playing != true) {
                  return IconButton(
                    icon: Icon(Icons.play_arrow),
                    iconSize: 64.0,
                    onPressed: _player.play,
                  );
                } else {
                  return IconButton(
                    icon: Icon(Icons.pause),
                    iconSize: 64.0,
                    onPressed: _player.pause,
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}