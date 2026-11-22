import 'package:flutter/material.dart';

import '../data/playlists.dart';
import '../models/playlist.dart';
import '../models/song.dart';

Future<String?> playlistName(BuildContext context, {String? initial}) {
  var name = initial ?? '';
  return showDialog<String>(
    context: context,
    builder:
        (ctx) => StatefulBuilder(
          builder:
              (ctx, setState) => AlertDialog(
                title: Text(
                  initial == null ? 'Nuova playlist' : 'Rinomina playlist',
                ),
                content: TextFormField(
                  initialValue: initial,
                  autofocus: true,
                  maxLength: 100,
                  decoration: const InputDecoration(labelText: 'Nome playlist'),
                  onChanged: (value) => setState(() => name = value.trim()),
                  onFieldSubmitted: (_) {
                    if (name.isNotEmpty) Navigator.pop(ctx, name);
                  },
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Annulla'),
                  ),
                  FilledButton(
                    onPressed:
                        name.isEmpty ? null : () => Navigator.pop(ctx, name),
                    child: Text(initial == null ? 'Crea' : 'Salva'),
                  ),
                ],
              ),
        ),
  );
}

Future<void> editPlaylist(
  BuildContext context,
  Future<void> Function() edit,
) async {
  try {
    await edit();
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Modifica della playlist non riuscita. Riprova.'),
        ),
      );
    }
  }
}

Future<void> addSongToPlaylist(
  BuildContext context,
  Song song,
  Playlists store,
  PlaylistLibrary library,
) async {
  // Isar auto-incremented IDs are positive.
  final selected = await showModalBottomSheet<int>(
    context: context,
    useSafeArea: true,
    builder:
        (ctx) => StreamBuilder<List<Playlist>>(
          stream: store.watch(),
          builder:
              (_, snapshot) => ListView(
                shrinkWrap: true,
                children: [
                  ListTile(
                    title: Text(
                      'Aggiungi a playlist',
                      style: Theme.of(ctx).textTheme.titleLarge,
                    ),
                    subtitle: Text(song.title),
                  ),
                  ListTile(
                    leading: const Icon(Icons.add),
                    title: const Text('Nuova playlist'),
                    onTap: () => Navigator.pop(ctx, 0),
                  ),
                  if (snapshot.hasError)
                    const ListTile(title: Text('Playlist non disponibili')),
                  for (final p in snapshot.data ?? <Playlist>[])
                    Builder(
                      builder: (_) {
                        final added = p.entries.any(
                          (e) =>
                              library.canonicalId(e.songId) == song.libraryId,
                        );
                        return ListTile(
                          title: Text(p.name),
                          leading: Icon(
                            added ? Icons.check : Icons.queue_music,
                          ),
                          enabled: !added,
                          subtitle: added ? const Text('Già presente') : null,
                          onTap: () => Navigator.pop(ctx, p.id),
                        );
                      },
                    ),
                ],
              ),
        ),
  );
  if (selected == null || !context.mounted) return;
  if (selected == 0) {
    final name = await playlistName(context);
    if (name == null || !context.mounted) return;
    await editPlaylist(context, () async {
      await store.create(name, firstSong: song);
    });
  } else {
    await editPlaylist(context, () => store.add(selected, [song], library));
  }
}

class PlaylistSongPicker extends StatefulWidget {
  const PlaylistSongPicker({
    super.key,
    required this.playlist,
    required this.library,
  });
  final Playlist playlist;
  final PlaylistLibrary library;
  @override
  State<PlaylistSongPicker> createState() => _PlaylistSongPickerState();
}

class _PlaylistSongPickerState extends State<PlaylistSongPicker> {
  late final _songs = widget.library.songs;
  late final _existing =
      widget.playlist.entries
          .map((e) => widget.library.canonicalId(e.songId))
          .toSet();
  final _selected = <Song>{};
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final songs = _songs.where((s) => s.matches(_query)).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Aggiungi brani')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Cerca un brano',
                prefixIcon: Icon(Icons.search),
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
                      itemBuilder: (_, index) {
                        final song = songs[index];
                        final added = _existing.contains(song.libraryId);
                        return CheckboxListTile(
                          title: Text(song.title),
                          subtitle: Text(song.artist),
                          value: added || _selected.contains(song),
                          onChanged:
                              added
                                  ? null
                                  : (value) => setState(() {
                                    if (value == true) {
                                      _selected.add(song);
                                    } else {
                                      _selected.remove(song);
                                    }
                                  }),
                        );
                      },
                    ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton(
            onPressed:
                _selected.isEmpty
                    ? null
                    : () => Navigator.pop(context, _selected.toList()),
            child: Text(
              _selected.isEmpty ? 'Aggiungi' : 'Aggiungi (${_selected.length})',
            ),
          ),
        ),
      ),
    );
  }
}
