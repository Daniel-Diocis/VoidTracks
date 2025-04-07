import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

void main() => runApp(MyApp());

// Entrata principale dell'app
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: MusicPlayer(),
    );
  }
}

// Widget principale con stato, contiene tutto il player
class MusicPlayer extends StatefulWidget {
  @override
  _MusicPlayerState createState() => _MusicPlayerState();
}

class _MusicPlayerState extends State<MusicPlayer> {
  late AudioPlayer _player;

  // Lista delle canzoni con titolo e percorso asset
  final List<Map<String, String>> songs = [
    {"title": "Joji - YEAH RIGHT", "asset": "assets/audio/musica1.mp3", "cover": "assets/images/cover1.jpg"},
    {"title": "C.R.O - Antes", "asset": "assets/audio/musica2.mp3", "cover": "assets/images/cover2.jpg"},
    {"title": "C.R.O - RUINAS", "asset": "assets/audio/musica3.mp3", "cover": "assets/images/cover2.jpg"},
    {"title": "C.R.O - Ciudad Gris", "asset": "assets/audio/musica4.mp3", "cover": "assets/images/cover2.jpg"},
    {"title": "C.R.O - COMO SE SIENTE", "asset": "assets/audio/musica5.mp3", "cover": "assets/images/cover2.jpg"},
    {"title": "Tiago PZK - Mi Corazón", "asset": "assets/audio/musica6.mp3", "cover": "assets/images/cover6.jpg"},
    {"title": "A\$AP Rocky - L\$D", "asset": "assets/audio/musica7.mp3", "cover": "assets/images/cover7.jpg"},
    {"title": "Mac Miller - Self Care", "asset": "assets/audio/musica8.mp3", "cover": "assets/images/cover8.jpg"},
    {"title": "Mac Miller - Good News", "asset": "assets/audio/musica9.mp3", "cover": "assets/images/cover9.jpg"},
    {"title": "Noah Cyrus, Lil Xan - Live or Die", "asset": "assets/audio/musica10.mp3", "cover": "assets/images/cover10.jpg"},
    {"title": "JPEGMAFIA - either on or off the drugs", "asset": "assets/audio/musica11.mp3", "cover": "assets/images/cover11.jpg"},
  ];

  String? _currentlyPlaying; // Nome del file in riproduzione (per confronto)
  String? _currentlyPlayingTitle; // Titolo umano da mostrare

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer(); // Inizializzazione del player audio
  }

  // Gestisce la riproduzione o pausa dei brani
  Future<void> playSong(String assetPath, String filename) async {
    try {
      final path = await loadAssetToFile(assetPath, filename);

      // Se si sta interagendo col brano già selezionato
      if (_currentlyPlaying == filename) {
        if (_player.playing) {
          await _player.pause(); // Metti in pausa
        } else {
          await _player.play(); // Riprendi
        }

        setState(() {
          _currentlyPlayingTitle = songs
              .firstWhere((s) => s['asset']!.split('/').last == filename)['title'];
        });

        return;
      }

      // Se stiamo cambiando brano
      await _player.stop(); // Ferma il precedente
      await _player.setFilePath(path); // Imposta il nuovo file

      // Aspetta che la durata venga caricata correttamente
      await _player.durationStream.firstWhere((d) => d != null);

      await _player.play(); // Riproduci

      // Aggiorna lo stato con nuovo brano e titolo
      setState(() {
        _currentlyPlaying = filename;
        _currentlyPlayingTitle = songs
            .firstWhere((s) => s['asset']!.split('/').last == filename)['title'];
      });
    } catch (e) {
      print("Errore nel caricamento: $e");
    }
  }

  // Formatta durata in mm:ss
  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  void dispose() {
    _player.dispose(); // Rilascia le risorse del player
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            // Miniatura dell’icona dell’app
            CircleAvatar(
              backgroundImage: AssetImage('assets/images/icon.png'),
              radius: 16,
            ),
            SizedBox(width: 8),
            Text("VoidTracks"),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_currentlyPlaying != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Titolo del brano in riproduzione
                  Row(
                    children: [
                      // Miniatura copertina brano
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          songs.firstWhere((s) => s['asset']!.split('/').last == _currentlyPlaying)['cover']!,
                          height: 48,
                          width: 48,
                          fit: BoxFit.cover,
                        ),
                      ),
                      SizedBox(width: 12),
                      // Titolo del brano
                      Expanded(
                        child: Text(
                          songs.firstWhere((s) => s['asset']!.split('/').last == _currentlyPlaying)['title']!,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  // STREAM 1: Durata del brano
                  StreamBuilder<Duration?>(
                    stream: _player.durationStream,
                    builder: (context, snapshot) {
                      final duration = snapshot.data ?? Duration.zero;

                      // STREAM 2: Posizione corrente
                      return StreamBuilder<Duration>(
                        stream: _player.positionStream,
                        builder: (context, snapshot) {
                          final position = snapshot.data ?? Duration.zero;

                          return Column(
                            children: [
                              // Seekbar
                              Slider(
                                min: 0,
                                max: duration.inMilliseconds.toDouble(),
                                value: position.inMilliseconds
                                    .clamp(0, duration.inMilliseconds)
                                    .toDouble(),
                                onChanged: (value) {
                                  _player.seek(Duration(milliseconds: value.toInt()));
                                },
                              ),
                              // Durata e tempo corrente
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(_formatDuration(position)),
                                  Text(_formatDuration(duration)),
                                ],
                              )
                            ],
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          // Lista dei brani
          Expanded(
            child: ListView.builder(
              itemCount: songs.length,
              itemBuilder: (context, index) {
                final song = songs[index];
                final isCurrent = _currentlyPlaying == song['asset']!.split('/').last;

                return ListTile(
                  title: Text(song['title']!),
                  trailing: StreamBuilder<PlayerState>(
                    stream: _player.playerStateStream,
                    builder: (context, snapshot) {
                      final playerState = snapshot.data;
                      final playing = playerState?.playing ?? false;

                      // Icona dinamica in base allo stato e al brano selezionato
                      final icon = isCurrent && playing ? Icons.pause : Icons.play_arrow;

                      return IconButton(
                        icon: Icon(icon),
                        onPressed: () async {
                          if (isCurrent) {
                            if (playing) {
                              await _player.pause();
                            } else {
                              await _player.play();
                            }
                          } else {
                            await playSong(
                              song['asset']!,
                              song['asset']!.split('/').last,
                            );
                          }
                        },
                      );
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

/// Copia l’asset audio nella memoria temporanea locale per poter essere riprodotto
Future<String> loadAssetToFile(String assetPath, String filename) async {
  final byteData = await rootBundle.load(assetPath); // Carica bytes dell’asset
  final dir = await getApplicationDocumentsDirectory(); // Ottieni directory temporanea
  final file = File('${dir.path}/$filename'); // Crea file con path assoluto

  await file.writeAsBytes(byteData.buffer.asUint8List(), flush: true); // Scrivi dati
  return file.path; // Ritorna il path
}