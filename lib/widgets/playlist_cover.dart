import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/playlist.dart';
import '../models/song.dart';
import 'artwork.dart';

class PlaylistCover extends StatelessWidget {
  const PlaylistCover(this.playlist, {super.key});
  final Playlist playlist;

  @override
  Widget build(BuildContext context) {
    final bytes = playlist.coverBytes;
    final colors = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox.square(
        dimension: 48,
        child:
            bytes == null
                ? ColoredBox(
                  color:
                      playlist.isFavorites
                          ? colors.primary
                          : colors.surfaceContainerHighest,
                  child: Icon(
                    playlist.isFavorites ? Icons.favorite : Icons.queue_music,
                    color:
                        playlist.isFavorites
                            ? colors.onPrimary
                            : colors.onSurfaceVariant,
                  ),
                )
                : Image.memory(
                  bytes is Uint8List ? bytes : Uint8List.fromList(bytes),
                  fit: BoxFit.cover,
                ),
      ),
    );
  }
}

Future<Uint8List> playlistThumbnail(Uri uri) async {
  final provider = ResizeImage(
    Artwork.providerFor(uri)!,
    width: 160,
    height: 160,
    policy: ResizeImagePolicy.fit,
  );
  final info = await loadArtwork(provider);
  try {
    final bytes = await info.image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) throw StateError('Copertina non disponibile');
    return bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
  } finally {
    info.dispose();
  }
}

class PlaylistCoverPicker extends StatefulWidget {
  const PlaylistCoverPicker(this.songs, {super.key});
  final List<Song> songs;
  @override
  State<PlaylistCoverPicker> createState() => _PlaylistCoverPickerState();
}

class _PlaylistCoverPickerState extends State<PlaylistCoverPicker> {
  String _query = '';
  Uri? _loading;
  Future<void> _choose(Song song) async {
    if (_loading != null) return;
    setState(() => _loading = song.cover);
    try {
      final bytes = await playlistThumbnail(song.cover);
      if (mounted) Navigator.pop(context, bytes);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossibile caricare la copertina. Riprova.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final songs = widget.songs.where((s) => s.matches(_query)).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Scegli copertina')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Cerca per brano, artista o album',
              ),
              onChanged:
                  (value) =>
                      setState(() => _query = value.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child:
                songs.isEmpty
                    ? const Center(child: Text('Nessun brano disponibile'))
                    : ListView.builder(
                      itemCount: songs.length,
                      itemBuilder: (_, i) {
                        final song = songs[i];
                        return ListTile(
                          leading: Artwork(song.cover),
                          title: Text(song.title),
                          subtitle: Text(song.artist),
                          trailing:
                              _loading == song.cover
                                  ? const CircularProgressIndicator()
                                  : null,
                          onTap: _loading == null ? () => _choose(song) : null,
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
