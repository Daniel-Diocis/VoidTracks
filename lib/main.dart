import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:path_provider/path_provider.dart';
import 'package:isar/isar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'models/track.dart';
import 'screens/now_playing_screen.dart';
import 'screens/market_screen.dart';
import 'screens/now_playing_market.dart';

late final Isar isar;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: "assets/.env");

  // Inizializzazione Supabase
  await Supabase.initialize(
    url: '${dotenv.env['SUPABASE_URL']}',
    anonKey: '${dotenv.env['SUPABASE_ANON_KEY']}',
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
  late TextEditingController _searchController;
  bool _showSearchBar = false;
  String _searchQuery = '';
  late ValueNotifier<Track?> _currentTrackNotifier;
  List<Track> _tracks = [];
  Track? _currentlyPlayingTrack;

  Future<void> _initTracks() async {
    final tracks = await isar.tracks.where().findAll();
    print("📀 Brani trovati nel DB locale: ${tracks.length}");
    for (final t in tracks) {
      print("🎵 ${t.titolo} - ${t.music_path} - ${t.cover_path}");
    }

    setState(() {
      _tracks = tracks;
    });
  }

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
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
      final path = track.music_path;
      final imagePath = track.cover_path;

      if (_currentlyPlayingTrack?.music_path == track.music_path) {
        if (_player.playing) {
          await _player.pause();
        } else {
          await _player.play();
        }

        setState(() {
          _currentlyPlayingTrack!.titolo = track.titolo;
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
              id: track.music_path,
              title: ('${track.artista} - ${track.titolo}'),
              album: track.album,
              artUri: Uri.file(track.cover_path),
              extras: {
                'cover': track.cover_path,
                'artist': track.artista,
                //'album': track.album,
                'duration': track.duration_ms,
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
          _currentlyPlayingTrack!.titolo = track.titolo;
          _currentTrackNotifier.value = track;
        });

        await _player.play(); // Avvia la riproduzione
    } catch (e) {
      print("Errore nel caricamento: $e");
    }
  }

  Future<void> eliminaBranoDaIsar(String musicPath) async {
    final brano = await isar.tracks.filter().music_pathEqualTo(musicPath).findFirst();

    if (brano != null) {
      final coverPath = brano.cover_path;

      // 🔍 Recupera tutti i brani con la stessa cover
      final altriBraniConStessaCover = await isar.tracks
          .filter()
          .cover_pathEqualTo(coverPath)
          .findAll();

      // Escludi il brano stesso (confronto sul music_path)
      final altriEffettivi = altriBraniConStessaCover.where((b) => b.music_path != musicPath).toList();

      // 🗑️ Elimina il file della musica
      final fileMusica = File(brano.music_path);
      if (await fileMusica.exists()) {
        await fileMusica.delete();
        print('🗑️ File musica eliminato: ${fileMusica.path}');
      }

      // 🗑️ Elimina la cover solo se non è usata da altri
      if (altriEffettivi.isEmpty) {
        final fileCover = File(coverPath);
        if (await fileCover.exists()) {
          await fileCover.delete();
          print('🗑️ Cover eliminata: ${fileCover.path}');
        }
      } else {
        print('✅ Cover mantenuta perché usata da altre canzoni.');
      }

      // 🔄 Elimina il record da Isar
      await isar.writeTxn(() async {
        await isar.tracks.delete(brano.id);
      });

      print('✅ Brano eliminato da Isar: ${brano.titolo}');
    } else {
      print('⚠️ Nessun brano trovato con path: $musicPath');
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
    _searchController.dispose();
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
    final query = _searchQuery.toLowerCase();

    final risultatiFiltrati = _tracks.where((track) {
            final query = _searchQuery.toLowerCase();
            return track.titolo.toLowerCase().contains(query) ||
                  track.artista.toLowerCase().contains(query) ||
                  track.album.toLowerCase().contains(query);
          }).toList();
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
        actions: [
          IconButton(
            icon: Icon(Icons.search),
            tooltip: 'Cerca',
            onPressed: () {
              setState(() {
                _showSearchBar = !_showSearchBar;
                _searchQuery = '';
                _searchController.clear();
              });
            },
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            tooltip: "Aggiorna brani",
            onPressed: () async {
              await _initTracks();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("🔁 Brani aggiornati dalla libreria"), duration: Duration(milliseconds: 800)),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_showSearchBar)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Cerca per titolo, artista o album',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                ),
              ),
            ),
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
                                  currentTrackNotifier: _currentTrackNotifier,
                                  onNext: skipToNext,
                                  onPrevious: skipToPrevious,
                                ),
                              ),
                            );
                          },
                          child:ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(_currentlyPlayingTrack!.cover_path),
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
                          '${_currentlyPlayingTrack!.artista} - ${_currentlyPlayingTrack!.titolo}',
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
            child: risultatiFiltrati.isEmpty
                ? Center(child: Text('🔍 Nessun risultato trovato'))
                : ListView.builder(
                    itemCount: risultatiFiltrati.length,
                    itemBuilder: (context, index) {
                      final track = risultatiFiltrati[index];
                      final isCurrent = _currentlyPlayingTrack?.music_path == track.music_path;

                      return DismissibleTrackTile(
                        track: track,
                        index: index,
                        isCurrent: isCurrent && (_player.playing),
                        onDelete: (path) async {
                          await eliminaBranoDaIsar(path);
                          setState(() {
                            _tracks.removeWhere((t) => t.music_path == path);
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('🗑️ Brano eliminato')),
                          );
                        },
                        onPlay: () => playTrack(track),
                      );
                    },
                  ),
          )
        ],
      ),
    );
  }
}

class DismissibleTrackTile extends StatefulWidget {
  final Track track;
  final int index;
  final bool isCurrent;
  final Function(String) onDelete;
  final Function() onPlay;

  const DismissibleTrackTile({
    required this.track,
    required this.index,
    required this.isCurrent,
    required this.onDelete,
    required this.onPlay,
    Key? key,
  }) : super(key: key);

  @override
  State<DismissibleTrackTile> createState() => _DismissibleTrackTileState();
}

class _DismissibleTrackTileState extends State<DismissibleTrackTile> {
  double _dragExtent = 0.0;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerMove: (event) {
        setState(() {
          _dragExtent += event.delta.dx;
        });
      },
      onPointerUp: (_) => setState(() => _dragExtent = 0),
      child: Dismissible(
        key: ValueKey(widget.track.music_path),
        direction: DismissDirection.startToEnd,
        background: Container(
          color: Colors.red.withOpacity((_dragExtent / 100).clamp(0, 1)),
          alignment: Alignment.centerLeft,
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Icon(Icons.delete, color: Colors.white),
        ),
        confirmDismiss: (direction) async {
          return await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text('Conferma eliminazione'),
              content: Text('Vuoi eliminare il brano "${widget.track.titolo}"?'),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text('Annulla')),
                TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text('Elimina')),
              ],
            ),
          );
        },
        onDismissed: (direction) async {
          await widget.onDelete(widget.track.music_path);
        },
        child: Opacity(
          opacity: (1 - (_dragExtent / 200).clamp(0.0, 0.5)), // sfuma fino a metà opacità
          child: ListTile(
            leading: Image.file(
              File(widget.track.cover_path),
              width: 50,
              height: 50,
              fit: BoxFit.cover,
            ),
            title: Text('${widget.track.artista} - ${widget.track.titolo}'),
            subtitle: Text(widget.track.album),
            trailing: IconButton(
              icon: Icon(
                widget.isCurrent ? Icons.pause : Icons.play_arrow,
              ),
              onPressed: widget.onPlay,
            ),
          ),
        ),
      ),
    );
  }
}