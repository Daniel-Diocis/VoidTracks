import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'now_playing_market.dart';
import 'package:isar/isar.dart';
import '../models/track.dart';
import '../main.dart';

class MarketScreen extends StatefulWidget {
  @override
  _MarketScreenState createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> {
  final client = Supabase.instance.client;
  final AudioPlayer _player = AudioPlayer();
  List<Map<String, dynamic>> braniConFile = [];
  late ValueNotifier<Map<String, dynamic>?> _currentMarketNotifier;
  bool loading = true;
  bool _showSearchBar = false;
  late TextEditingController _searchController;
  String _searchQuery = '';
  Map<String, String> _localTimestamps = {};

  @override
  void initState() {
    super.initState();
    _setupAudioSession();
    _currentMarketNotifier = ValueNotifier(null);
    _searchController = TextEditingController();
    _player.processingStateStream.listen((state) async {
      if (state == ProcessingState.completed) {
        skipToNext();
      }
    });
    _loadBraniConFile();
  }

  Future<void> _setupAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(AudioSessionConfiguration.music());
  }

  Future<void> _loadBraniConFile() async {
    try {
      final response = await client.from('brani').select();
      final List<Map<String, dynamic>> brani = List<Map<String, dynamic>>.from(response);
      final directory = await getApplicationDocumentsDirectory();

      await _loadLocalTimestamps(directory);

      List<Map<String, dynamic>> risultati = [];

      for (var brano in brani) {
        final id = brano['music_path'];
        final updated_at = brano['updated_at'];
        final localUpdated = _localTimestamps[id];

        final shouldDownload = localUpdated == null || localUpdated != updated_at;

        final musicFilePath = await _getOrDownloadFile(
          bucket: 'music',
          path: brano['music_path'],
          saveDir: directory.path,
          forceDownload: shouldDownload,
        );
        final coverFilePath = await _getOrDownloadFile(
          bucket: 'cover',
          path: brano['cover_path'],
          saveDir: directory.path,
          forceDownload: shouldDownload,
        );

        if (shouldDownload) {
          _localTimestamps[id] = updated_at;
          //await addOrUpdateTrack(brano, musicFilePath, coverFilePath);
        }

        risultati.add({
          'titolo': brano['titolo'],
          'artista': brano['artista'],
          'album': brano['album'],
          'music_path': musicFilePath,
          'cover_path': coverFilePath,
          'updated_at': updated_at,
        });
      }

      await _saveLocalTimestamps(directory);

      risultati.sort((a, b) {
        final artistaA = a['artista'].toString().toLowerCase();
        final artistaB = b['artista'].toString().toLowerCase();
        final confrontoArtista = artistaA.compareTo(artistaB);

        if (confrontoArtista != 0) {
          return confrontoArtista; // artisti diversi → ordina per artista
        }

        // artisti uguali → ordina per titolo
        final titoloA = a['titolo'].toString().toLowerCase();
        final titoloB = b['titolo'].toString().toLowerCase();
        return titoloA.compareTo(titoloB);
      });

      setState(() {
        braniConFile = risultati;
        loading = false;
      });
    } catch (e) {
      print("❌ Errore nel caricamento dei brani: $e");
      setState(() => loading = false);
    }
  }
  
  Future<void> addOrUpdateTrack(Map<String, dynamic> brano, String music_path, String cover_path) async {
    final track = Track.fromSupabase(brano)
      ..music_path = music_path
      ..cover_path = cover_path;

    final existing = await isar.tracks
        .filter()
        .music_pathEqualTo(track.music_path)
        .findFirst();

    if (existing == null || existing.updated_at != track.updated_at) {
      await isar.writeTxn(() async {
        await isar.tracks.put(track);
      });
      print("✅ Brano salvato o aggiornato: ${track.titolo}");
    } else {
      print("⚠️ Brano già aggiornato localmente: ${track.titolo}");
    }
  }

  Future<void> _scaricaBrano(Map<String, dynamic> brano) async {
    print('📦 Inizio download del brano: ${brano['titolo']}');

    final musicPathRemote = brano['music_path'];
    final coverPathRemote = brano['cover_path'];
    print('🧩 Contenuto di brano: $brano');

    if (musicPathRemote == null || coverPathRemote == null) {
      print('🚫 Errore: music_path o cover_path');
      return;
    }

    final dir = await getApplicationDocumentsDirectory();

    print('⬇️ Scarico musica da "$musicPathRemote"');
    final music_path = await _getOrDownloadFile(
      bucket: 'music',
      path: musicPathRemote,
      saveDir: dir.path,
      forceDownload: true,
    );

    print('⬇️ Scarico cover da "$coverPathRemote"');
    final cover_path = await _getOrDownloadFile(
      bucket: 'cover',
      path: coverPathRemote,
      saveDir: dir.path,
      forceDownload: true,
    );

    final nuovoTrack = Track()
      ..titolo = brano['titolo']
      ..artista = brano['artista']
      ..album = brano['album']
      ..music_path = music_path
      ..cover_path = cover_path
      ..updated_at = brano['updated_at']
      ..duration_ms = null;

    await isar.writeTxn(() async {
      await isar.tracks.put(nuovoTrack);
    });

    print('✅ Brano scaricato e salvato: ${nuovoTrack.titolo}');
    print('📁 Path file: $music_path');
    print('🖼️ Path cover: $cover_path');

    // 🧠 Aggiorna il timestamp locale
    _localTimestamps[brano['music_path']] = brano['updated_at'];
    await _saveLocalTimestamps(dir);

    // ✅ Aggiorna la lista a schermo
    setState(() {
      final index = braniConFile.indexWhere((b) => b['music_path'] == music_path);

      final nuovoBrano = {
        'titolo': brano['titolo'],
        'artista': brano['artista'],
        'album': brano['album'],
        'music_path': music_path,
        'cover_path': cover_path,
        'updated_at': brano['updated_at'],
      };

      if (index != -1) {
        braniConFile[index] = nuovoBrano; // 🔄 Sostituisce mantenendo la posizione
      } else {
        braniConFile.add(nuovoBrano); // ➕ Solo se nuovo
      }
    });
  }

  Future<void> _loadLocalTimestamps(Directory dir) async {
    final file = File('${dir.path}/timestamps.json');
    if (await file.exists()) {
      final contents = await file.readAsString();
      _localTimestamps = Map<String, String>.from(jsonDecode(contents));
    }
  }

  Future<void> _saveLocalTimestamps(Directory dir) async {
    final file = File('${dir.path}/timestamps.json');
    await file.writeAsString(jsonEncode(_localTimestamps));
  }

  Future<String> _getOrDownloadFile({
    required String bucket,
    required String path,
    required String saveDir,
    required bool forceDownload,
  }) async {
    final filename = path.split('/').last; // ✅ Solo il nome del file
    final file = File('$saveDir/$filename');

    if (!forceDownload && await file.exists()) {
      print('📂 File già esistente, non scarico: ${file.path}');
      return file.path;
    }

    print('⬇️ Scaricamento da bucket "$bucket" path "$filename"...');

    final response = await client.storage.from(bucket).download(filename);
    final bytes = response;

    await file.create(recursive: true);
    await file.writeAsBytes(bytes);

    print('✅ File scaricato e salvato in: ${file.path}');
    return file.path;
  }

  Future<void> _playTrack(Map<String, dynamic> brano) async {
    try {
      final filename = File(brano['music_path']).uri.pathSegments.last;
      final sameTrack = _currentMarketNotifier.value?['music_path'] == brano['music_path'];
      _currentMarketNotifier.value = brano;

      if (sameTrack) {
        if (_player.playing) {
          await _player.pause(); // Metti in pausa
        } else {
          await _player.play(); // Riprendi
        }

        return;
      }

      final imagePath = brano['cover_path'];

      await _player.stop(); // Ferma il precedente
      await _player.setAudioSource(
        AudioSource.file(
          brano['music_path'],
          tag: MediaItem(
            id: filename,
            title: brano['titolo'],
            artist: brano['artista'],
            album: brano['album'],
            artUri: Uri.file(imagePath),
            extras: {
              'skipToNext': true,
              'skipToPrevious': true,
            },
          ),
        ),
      );

      await _player.durationStream.firstWhere((d) => d != null);

      setState(() {
        _currentMarketNotifier.value = brano;
      });

      await _player.play();
    } catch (e) {
      print("❌ Errore durante la riproduzione: $e");
    }
  }

  void skipToNext() async {
    final currentIndex = braniConFile.indexWhere((b) => b['music_path'] == _currentMarketNotifier.value?['music_path']);
    final nextIndex = (currentIndex + 1) % braniConFile.length;
    final next = braniConFile[nextIndex];
    await _playTrack(next);
  }

  void skipToPrevious() async {
    final currentIndex = braniConFile.indexWhere((b) => b['music_path'] == _currentMarketNotifier.value?['music_path']);
    final prevIndex = (currentIndex - 1 + braniConFile.length) % braniConFile.length;
    final prev = braniConFile[prevIndex];
    await _playTrack(prev);
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  @override
  void dispose() {
    _searchController.dispose();
    _player.dispose();
    _currentMarketNotifier.dispose();
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
            Text("VoidMarket"),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search),
            tooltip: 'Cerca',
            onPressed: () {
              setState(() {
                _showSearchBar = !_showSearchBar;
                _searchQuery = ''; // resetto query se nascondo barra
              });
            },
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            tooltip: 'Aggiorna brani',
            onPressed: () async {
              setState(() => loading = true);
              await _loadBraniConFile();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("🔁 Brani aggiornati dal server"), duration: Duration(milliseconds: 800)),
              );
            },
          ),
        ],
      ),
      body: loading
        ? Center(child: CircularProgressIndicator())
        : Column(
            children: [
              // 🔍 Searchbar sempre visibile quando attiva
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

              // 🎵 Brano attualmente in riproduzione (se esiste)
              if (_currentMarketNotifier.value != null)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => NowPlayingMarket(
                                      player: _player,
                                      currentTrackNotifier: _currentMarketNotifier,
                                      onNext: skipToNext,
                                      onPrevious: skipToPrevious,
                                    ),
                                  ),
                                );
                              },
                              child: Image.file(
                                File(_currentMarketNotifier.value!['cover_path']),
                                height: 48,
                                width: 48,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '${_currentMarketNotifier.value!['artista']} - ${_currentMarketNotifier.value!['titolo']}',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      StreamBuilder<Duration?>(
                        stream: _player.durationStream,
                        builder: (context, snapshot) {
                          final duration = snapshot.data ?? Duration.zero;
                          return StreamBuilder<Duration>(
                            stream: _player.positionStream,
                            builder: (context, snapshot) {
                              final position = snapshot.data ?? Duration.zero;
                              return Column(
                                children: [
                                  Slider(
                                    min: 0,
                                    max: duration.inMilliseconds.toDouble(),
                                    value: position.inMilliseconds.clamp(0, duration.inMilliseconds).toDouble(),
                                    onChanged: (value) {
                                      _player.seek(Duration(milliseconds: value.toInt()));
                                    },
                                  ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(_formatDuration(position)),
                                      Text(_formatDuration(duration)),
                                    ],
                                  ),
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

              // 🎧 Lista dei brani
              Expanded(
                child: ListView.builder(
                  itemCount: braniConFile.length,
                  itemBuilder: (context, index) {
                    final brano = braniConFile[index];
                    final isCurrent = _currentMarketNotifier.value?['music_path'] == brano['music_path'];

                    Icon trailingIcon;
                    VoidCallback? downloadAction;

                    return FutureBuilder<Track?>(
                      future: isar.tracks
                          .filter()
                          .music_pathEqualTo(brano['music_path'])
                          .findFirst(),
                      builder: (context, snapshot) {
                        final downloaded = snapshot.data;
                        final isScaricato = downloaded != null;
                        final aggiornato = downloaded?.updated_at == brano['updated_at'];

                        if (!isScaricato) {
                          trailingIcon = Icon(Icons.download);
                          downloadAction = () async {
                            await _scaricaBrano(brano);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('✅ Brano scaricato: "${brano['titolo']}"')),
                            );
                          };
                        } else if (!aggiornato) {
                          trailingIcon = Icon(Icons.system_update);
                          downloadAction = () async {
                            await _scaricaBrano(brano);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('🔁 Brano aggiornato: "${brano['titolo']}"')),
                            );
                          };
                        } else {
                          trailingIcon = Icon(Icons.check_circle, color: Colors.green);
                          downloadAction = null;
                        }

                        return ListTile(
                          leading: Image.file(
                            File(brano['cover_path']),
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                          ),
                          title: Text('${brano['artista']} - ${brano['titolo']}'),
                          subtitle: Text(brano['album']),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: trailingIcon,
                                onPressed: downloadAction,
                              ),
                              IconButton(
                                icon: Icon(
                                  isCurrent && (_player.playing) ? Icons.pause : Icons.play_arrow,
                                ),
                                onPressed: () => _playTrack(brano),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
    );
  }
}
