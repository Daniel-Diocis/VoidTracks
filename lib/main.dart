import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:path_provider/path_provider.dart';
import 'package:isar/isar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/track.dart';
import 'screens/now_playing_screen.dart';
import 'screens/market_screen.dart';

late Isar isar;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inizializzazione Supabase
  await Supabase.initialize(
    url: 'https://igohvppfcsipbmzpckei.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imlnb2h2cHBmY3NpcGJtenBja2VpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDQxMTc2MjcsImV4cCI6MjA1OTY5MzYyN30.HVORhtRVtZdrMN6TslgVyVCI474Lan5ScH9ri_W3alo',
  );

  // Inizializzazione Isar
  final dir = await getApplicationDocumentsDirectory();
  isar = await Isar.open([
    TrackSchema
  ], directory: dir.path);

  // Inizializzazione JustAudioBackground
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.tuaapp.channel.audio',
    androidNotificationChannelName: 'Riproduzione audio',
    androidNotificationOngoing: true,
    androidNotificationIcon: 'drawable/ic_notification',
  );

  runApp(MyApp());
}

// Entrata principale dell'app
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: MainNavigation(),
    );
  }
}

// Widget principale con stato, contiene tutto il player
class MainNavigation extends StatefulWidget {
  @override
  _MainNavigationState createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    MusicPlayer(),         // Home / Player
    MarketScreen(),        // Placeholder per il Market
  ];
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart),
            label: 'Market',
          ),
        ],
      ),
    );
  }
}

class MusicPlayer extends StatefulWidget {
  @override
  _MusicPlayerState createState() => _MusicPlayerState();
}

class _MusicPlayerState extends State<MusicPlayer> {
  late AudioPlayer _player;
  late ValueNotifier<Track?> _currentTrackNotifier;
  List<Track> _tracks = [];
  Track? _currentlyPlayingTrack;

  Future<void> _initTracks() async {
    await isar.writeTxn(() async {
      await isar.tracks.clear(); // 🔥 Pulisce il database
    });

    await populateTracksIfEmpty();

    final tracks = await isar.tracks.where().findAll();
    setState(() {
      _tracks = tracks;
    });
  }

  Future<void> populateTracksIfEmpty() async {
    final List<Track> tracks = [
      Track()
        ..title = "YEAH RIGHT"
        ..artist = "Joji"
        ..album = "Ballads 1"
        ..path = "assets/audio/musica1.mp3"
        ..cover = "assets/images/cover1.jpg",
      Track()
        ..title = "Antes"
        ..artist = "C.R.O"
        ..album = "Rock"
        ..path = "assets/audio/musica2.mp3"
        ..cover = "assets/images/cover2.jpg",
      Track()
        ..title = "RUINAS"
        ..artist = "C.R.O"
        ..album = "Rock"
        ..path = "assets/audio/musica3.mp3"
        ..cover = "assets/images/cover2.jpg",
      Track()
        ..title = "Ciudad Gris"
        ..artist = "C.R.O"
        ..album = "Rock"
        ..path = "assets/audio/musica4.mp3"
        ..cover = "assets/images/cover2.jpg",
      Track()
        ..title = "COMO SE SIENTE"
        ..artist = "C.R.O"
        ..album = "Rock"
        ..path = "assets/audio/musica5.mp3"
        ..cover = "assets/images/cover2.jpg",
      Track()
        ..title = "Mi Corazón"
        ..artist = "Tiago PZK"
        ..album = "Mi Corazón"
        ..path = "assets/audio/musica6.mp3"
        ..cover = "assets/images/cover6.jpg",
      Track()
        ..title = "L\$D"
        ..artist = "A\$AP Rocky"
        ..album = "AT.LONG.LAST.A\$AP."
        ..path = "assets/audio/musica7.mp3"
        ..cover = "assets/images/cover7.jpg",
      Track()
        ..title = "Demons"
        ..artist = "A\$AP Rocky"
        ..album = "LIVE.LOVE.A\$AP"
        ..path = "assets/audio/musica8.mp3"
        ..cover = "assets/images/cover8.jpg",
      Track()
        ..title = "Sandman"
        ..artist = "A\$AP Rocky"
        ..album = "LIVE.LOVE.A\$AP"
        ..path = "assets/audio/musica9.mp3"
        ..cover = "assets/images/cover8.jpg",
      Track()
        ..title = "Sundress"
        ..artist = "A\$AP Rocky"
        ..album = "Sundress"
        ..path = "assets/audio/musica10.mp3"
        ..cover = "assets/images/cover10.jpg",
      Track()
        ..title = "Self Care"
        ..artist = "Mac Miller"
        ..album = "Swimming"
        ..path = "assets/audio/musica11.mp3"
        ..cover = "assets/images/cover11.jpg",
      Track()
        ..title = "Good News"
        ..artist = "Mac Miller"
        ..album = "Circles"
        ..path = "assets/audio/musica12.mp3"
        ..cover = "assets/images/cover12.jpg",
      Track()
        ..title = "Live or Die"
        ..artist = "Noah Cyrus, Lil Xan"
        ..album = "Live or Die"
        ..path = "assets/audio/musica13.mp3"
        ..cover = "assets/images/cover13.jpg",
      Track()
        ..title = "either on or off the drugs"
        ..artist = "JPEGMAFIA"
        ..album = "I LAY DOWN MY LIFE FOR YOU"
        ..path = "assets/audio/musica14.mp3"
        ..cover = "assets/images/cover14.jpg",
    ];
    await isar.writeTxn(() async {
      await isar.tracks.putAll(tracks);
    });
  }

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _currentTrackNotifier = ValueNotifier(null);
    _initTracks();

    // Quando la canzone termina naturalmente
    _player.processingStateStream.listen((state) async {
      if (state == ProcessingState.completed) {
        skipToNext();
      }
    });
  }

  // Gestisce la riproduzione o pausa dei brani
  Future<void> playTrack(Track track) async {
    try {
      final path = await loadAssetToFile(track.path, track.path.split('/').last);
      final imagePath = await loadAssetToFile(track.cover!, track.cover!.split('/').last);

      if (_currentlyPlayingTrack?.path == track.path) {
        if (_player.playing) {
          await _player.pause();
        } else {
          await _player.play();
        }

        setState(() {
          _currentlyPlayingTrack!.title = track.title;
          _currentTrackNotifier.value = track;
        });

        return;
      }
        // Se stiamo cambiando brano
        await _player.stop(); // Ferma il precedente
        await _player.setAudioSource( // Dice al lettore audio di caricare un nuovo brano
          AudioSource.file( // Specifico che la sorgente è un file locale
            path,
            tag: MediaItem( // Fornisco le informazioni da mostrare nella notifica
              id: track.path,
              title: ('${track.artist} - ${track.title}'),
              album: track.album,
              artUri: Uri.file(imagePath),
              extras: {
                //'cover': imagePath,
                'artist': track.artist,
                //'album': track.album,
                'duration': track.durationMs,
                'skipToNext': true,
                'skipToPrevious': true,
              },
              
            ),
          ),
        );

        // Aspetta che la durata venga caricata correttamente
        await _player.durationStream.firstWhere((d) => d != null);

        // Aggiorna lo stato PRIMA di avviare la riproduzione
        setState(() {
          _currentlyPlayingTrack = track;
          _currentlyPlayingTrack!.title = track.title;
          _currentTrackNotifier.value = track;
        });

        await _player.play(); // Avvia la riproduzione
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
    _player.dispose();  // Rilascia le risorse del player
    super.dispose();
  }


  void skipToNext() async {
    if (_currentlyPlayingTrack == null) return;
    final currentIndex = _tracks.indexOf(_currentlyPlayingTrack!);
    final nextIndex = (currentIndex + 1) % _tracks.length;
    final nextTrack = _tracks[nextIndex];
    await playTrack(nextTrack);
  }

  void skipToPrevious() async {
    if (_currentlyPlayingTrack == null) return;
    final currentIndex = _tracks.indexOf(_currentlyPlayingTrack!);
    final prevIndex = (currentIndex - 1 + _tracks.length) % _tracks.length;
    final prevTrack = _tracks[prevIndex];
    await playTrack(prevTrack);
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
          if (_currentlyPlayingTrack != null)
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
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => NowPlayingScreen(
                                  player: _player,
                                  trackNotifier: _currentTrackNotifier,
                                  onNext: skipToNext,
                                  onPrevious: skipToPrevious,
                                ),
                              ),
                            );
                          },
                          child:ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.asset(
                              _currentlyPlayingTrack!.cover!,
                              height: 48,
                              width: 48,
                              fit: BoxFit.cover,
                              ),
                            ),
                        ),
                      ),
                      SizedBox(width: 12),
                      // Titolo del brano
                      Expanded(
                        child: Text(
                          '${_currentlyPlayingTrack!.artist} - ${_currentlyPlayingTrack!.title}',
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
                          
                          // STREAM 3: Stato del player
                          return Column(
                            children: [
                              // STREAM 4: [Seekbar] Slider per la posizione e durata del brano
                              Slider(
                                min: 0,
                                max: duration.inMilliseconds.toDouble(),
                                value: position.inMilliseconds.clamp(0, duration.inMilliseconds).toDouble(),
                                onChanged: (value) {
                                  _player.seek(Duration(milliseconds: value.toInt()));
                                },
                              ),
                              // STREAM 5: [Durata e tempo corrente] Testo con la durata e posizione
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(_formatDuration(position)),
                                  Text(_formatDuration(duration)),
                                ],
                              ),

                              // STREAM 6: [Controlli] Icone per il controllo della riproduzione
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.skip_previous),
                                    iconSize: 36,
                                    onPressed: skipToPrevious,
                                  ),
                                  StreamBuilder<PlayerState>(
                                    stream: _player.playerStateStream,
                                    builder: (context, snapshot) {
                                      final playing = snapshot.data?.playing ?? false;
                                      final icon = playing ? Icons.pause_circle_filled : Icons.play_circle_filled;
                                      
                                      return IconButton(
                                        icon: Icon(icon),
                                        iconSize: 48,
                                        onPressed: () async {
                                          if (_player.playing) {
                                            await _player.pause();
                                          } else {
                                            await _player.play();
                                          }
                                        },
                                      );
                                    },
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.skip_next),
                                    iconSize: 36,
                                    onPressed: skipToNext,
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: _tracks.length,
              itemBuilder: (context, index) {
                final track = _tracks[index];
                final isCurrent = _currentlyPlayingTrack?.path == track.path;
                return ListTile(
                  title: Text('${track.artist} - ${track.title}'),
                  trailing: StreamBuilder<PlayerState>(
                    stream: _player.playerStateStream,
                    builder: (context, snapshot) {
                      final playing = snapshot.data?.playing ?? false;

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
                            await playTrack(track);
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
  final byteData = await rootBundle.load(assetPath);  // Carica bytes dell’asset
  final dir = await getApplicationDocumentsDirectory(); // Ottieni directory temporanea
  final file = File('${dir.path}/$filename'); // Crea file con path assoluto
  await file.writeAsBytes(byteData.buffer.asUint8List(), flush: true);  // Scrivi dati
  return file.path; // Ritorna il path
}