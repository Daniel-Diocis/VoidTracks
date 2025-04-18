import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio_background/just_audio_background.dart';

class MarketScreen extends StatefulWidget {
  @override
  _MarketScreenState createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> {
  final client = Supabase.instance.client;
  final AudioPlayer _player = AudioPlayer();
  List<Map<String, dynamic>> braniConFile = [];
  Map<String, dynamic>? _currentlyPlaying;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _setupAudioSession();
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

      List<Map<String, dynamic>> risultati = [];

      for (var brano in brani) {
        final musicFilePath = await _downloadFileFromBucket(
          bucket: 'music',
          path: brano['music_path'],
          saveDir: directory.path,
        );
        final coverFilePath = await _downloadFileFromBucket(
          bucket: 'cover',
          path: brano['cover_path'],
          saveDir: directory.path,
        );
        risultati.add({
          'titolo': brano['titolo'],
          'artista': brano['artista'],
          'album': brano['album'],
          'musicPath': musicFilePath,
          'coverPath': coverFilePath,
        });
      }

      setState(() {
        braniConFile = risultati;
        loading = false;
      });
    } catch (e) {
      print("❌ Errore nel caricamento dei brani: $e");
      setState(() => loading = false);
    }
  }

  Future<String> _downloadFileFromBucket({
    required String bucket,
    required String path,
    required String saveDir,
  }) async {
    final response = await client.storage.from(bucket).download(path);
    final bytes = response;
    final file = File('$saveDir/$path');
    await file.create(recursive: true);
    await file.writeAsBytes(bytes);
    return file.path;
  }

  Future<void> _playTrack(Map<String, dynamic> brano) async {
    if (_currentlyPlaying?['musicPath'] == brano['musicPath']) {
      if (_player.playing) {
        await _player.pause();
      } else {
        await _player.play();
      }
      setState(() {}); // aggiorna l'icona
      return;
    }

    try {
      await _player.setAudioSource(
        AudioSource.file(
          brano['musicPath'],
          tag: MediaItem(
            id: brano['musicPath'],
            title: brano['titolo'],
            artist: brano['artista'],
            album: brano['album'],
            artUri: Uri.file(brano['coverPath']),
          ),
        ),
      );
      await _player.play();
      setState(() {
        _currentlyPlaying = brano;
      });
    } catch (e) {
      print("❌ Errore durante la riproduzione: $e");
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Widget _buildSeekBar() {
    return StreamBuilder<Duration>(
      stream: _player.positionStream,
      builder: (context, snapshot) {
        final position = snapshot.data ?? Duration.zero;
        final duration = _player.duration ?? Duration.zero;
        return Column(
          children: [
            Slider(
              value: position.inMilliseconds.clamp(0, duration.inMilliseconds).toDouble(),
              max: duration.inMilliseconds.toDouble(),
              onChanged: (value) {
                _player.seek(Duration(milliseconds: value.toInt()));
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_formatDuration(position)),
                  Text(_formatDuration(duration)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundImage: AssetImage('assets/images/icon.png'),
              radius: 16,
            ),
            SizedBox(width: 8),
            Text("VoidMarket"),
          ],
        ),
      ),
      body: loading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_currentlyPlaying != null) ...[
                  ListTile(
                    leading: Image.file(File(_currentlyPlaying!['coverPath']), width: 50, height: 50, fit: BoxFit.cover),
                    title: Text('${_currentlyPlaying!['artista']} - ${_currentlyPlaying!['titolo']}'),
                    subtitle: Text(_currentlyPlaying!['album']),
                    trailing: IconButton(
                      icon: Icon(_player.playing ? Icons.pause : Icons.play_arrow),
                      onPressed: () => _playTrack(_currentlyPlaying!),
                    ),
                  ),
                  _buildSeekBar(),
                ],
                Expanded(
                  child: ListView.builder(
                    itemCount: braniConFile.length,
                    itemBuilder: (context, index) {
                      final brano = braniConFile[index];
                      final isCurrent = _currentlyPlaying?['musicPath'] == brano['musicPath'];
                      return ListTile(
                        leading: Image.file(File(brano['coverPath']), width: 50, height: 50, fit: BoxFit.cover),
                        title: Text('${brano['artista']} - ${brano['titolo']}'),
                        subtitle: Text(brano['album']),
                        trailing: IconButton(
                          icon: Icon(isCurrent && _player.playing ? Icons.pause : Icons.play_arrow),
                          onPressed: () => _playTrack(brano),
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