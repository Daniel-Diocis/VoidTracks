import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

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
  final List<Map<String, String>> songs = [
    {"title": "Joji - YEAH RIGHT", "asset": "assets/audio/musica1.mp3"},
    {"title": "C.R.O - Antes", "asset": "assets/audio/musica2.mp3"},
    {"title": "C.R.O - RUINAS", "asset": "assets/audio/musica3.mp3"},
    {"title": "C.R.O - Ciudad Gris", "asset": "assets/audio/musica4.mp3"},
    {"title": "C.R.O - COMO SE SIENTE", "asset": "assets/audio/musica5.mp3"},
    {"title": "Tiago PZK - Mi Corazón", "asset": "assets/audio/musica6.mp3"},
    {"title": "JPEGMAFIA - either on or off the drugs", "asset": "assets/audio/musica11.mp3"},
  ];
  String? _currentlyPlaying;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
  }

  Future<void> playSong(String assetPath, String filename) async {
    try {
      final path = await loadAssetToFile(assetPath, filename);
      await _player.setFilePath(path);
      await _player.play();
      setState(() {
        _currentlyPlaying = filename;
      });
    } catch (e) {
      print("Errore nel caricamento: $e");
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("VoidTracks 🎵")),
      body: Column(
        children: [
          if (_currentlyPlaying != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text("🎧 In riproduzione: $_currentlyPlaying"),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: songs.length,
              itemBuilder: (context, index) {
                final song = songs[index];
                bool isCurrent = _currentlyPlaying == song['asset']!.split('/').last;
                return ListTile(
                  title: Text(song['title']!),
                  trailing: IconButton(
                    icon: Icon(
                      isCurrent && _player.playing ? Icons.pause : Icons.play_arrow,
                    ),
                    onPressed: () async {
                      if (isCurrent) {
                        if (_player.playing) {
                          await _player.pause();
                        } else {
                          await _player.play();
                        }
                        setState(() {}); // aggiorna icona
                      } else {
                        await playSong(song['asset']!, song['asset']!.split('/').last);
                      }
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Copia l’asset nel file system locale per essere riprodotto
Future<String> loadAssetToFile(String assetPath, String filename) async {
  final byteData = await rootBundle.load(assetPath);
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/$filename');

  await file.writeAsBytes(byteData.buffer.asUint8List(), flush: true);
  return file.path;
}