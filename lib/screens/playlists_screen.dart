import 'package:flutter/material.dart';

import '../data/playlists.dart';
import '../models/playlist.dart';
import '../models/song.dart';
import '../widgets/artwork.dart';
import '../widgets/playlist_cover.dart';
import '../widgets/swipe_remove.dart';
import '../widgets/playlist_dialogs.dart';

class PlaylistsScreen extends StatefulWidget {
  const PlaylistsScreen({
    super.key,
    required this.store,
    required this.library,
    required this.onSelect,
    required this.active,
    this.currentId,
  });
  final Playlists store;
  final PlaylistLibrary library;
  final void Function(List<Song>, Song) onSelect;
  final bool active;
  final String? currentId;

  @override
  State<PlaylistsScreen> createState() => _PlaylistsScreenState();
}

class _PlaylistsScreenState extends State<PlaylistsScreen> {
  late final _playlists = widget.store.watch();
  int? _opened;

  Future<void> _create() async {
    final name = await playlistName(context);
    if (name == null || !mounted) return;
    await editPlaylist(context, () async {
      final id = await widget.store.create(name);
      if (mounted) setState(() => _opened = id);
    });
  }

  Future<void> _menu(Playlist playlist, String action) async {
    if (action == 'cover') {
      final bytes = await Navigator.push<List<int>>(
        context,
        MaterialPageRoute(
          builder: (_) => PlaylistCoverPicker(widget.library.songs),
        ),
      );
      if (bytes != null && mounted) {
        await editPlaylist(
          context,
          () => widget.store.setCover(playlist.id, bytes),
        );
      }
      return;
    }
    if (action == 'rename') {
      final name = await playlistName(context, initial: playlist.name);
      if (name != null && mounted) {
        await editPlaylist(
          context,
          () => widget.store.rename(playlist.id, name),
        );
      }
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Eliminare la playlist?'),
            content: Text(playlist.name),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annulla'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Elimina'),
              ),
            ],
          ),
    );
    if (confirmed == true && mounted) {
      await editPlaylist(context, () => widget.store.delete(playlist.id));
    }
  }

  Future<void> _pick(Playlist playlist) async {
    final songs = await Navigator.push<List<Song>>(
      context,
      MaterialPageRoute(
        builder:
            (_) =>
                PlaylistSongPicker(playlist: playlist, library: widget.library),
      ),
    );
    if (songs != null && mounted) {
      await editPlaylist(
        context,
        () => widget.store.add(playlist.id, songs, widget.library),
      );
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Playlist>>(
    stream: _playlists,
    builder: (_, snapshot) {
      final playlists = snapshot.data ?? [];
      final playlist = playlists.where((p) => p.id == _opened).firstOrNull;
      if (playlist != null) {
        return PopScope(
          canPop: !widget.active,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && widget.active) setState(() => _opened = null);
          },
          child: Scaffold(
            appBar: AppBar(
              leading: BackButton(
                onPressed: () => setState(() => _opened = null),
              ),
              title: Text(playlist.name),
              actions: [
                IconButton(
                  tooltip: 'Aggiungi brani',
                  icon: const Icon(Icons.playlist_add),
                  onPressed: () => _pick(playlist),
                ),
              ],
            ),
            body:
                playlist.entries.isEmpty
                    ? Center(
                      child: OutlinedButton.icon(
                        onPressed: () => _pick(playlist),
                        icon: const Icon(Icons.add),
                        label: const Text('Aggiungi i primi brani'),
                      ),
                    )
                    : _tracks(playlist),
          ),
        );
      }
      return Scaffold(
        appBar: AppBar(
          title: const Text('Playlist'),
          actions: [
            IconButton(
              tooltip: 'Nuova playlist',
              icon: const Icon(Icons.add),
              onPressed: _create,
            ),
          ],
        ),
        body:
            snapshot.hasError
                ? const Center(child: Text('Playlist non disponibili'))
                : !snapshot.hasData
                ? const Center(child: CircularProgressIndicator())
                : playlists.isEmpty
                ? Center(
                  child: OutlinedButton.icon(
                    onPressed: _create,
                    icon: const Icon(Icons.playlist_add),
                    label: const Text('Crea la prima playlist'),
                  ),
                )
                : ListView.builder(
                  itemCount: playlists.length,
                  itemBuilder: (_, i) {
                    final p = playlists[i];
                    return ListTile(
                      leading: PlaylistCover(p),
                      title: Text(p.name),
                      subtitle: Text(
                        p.entries.length == 1
                            ? '1 brano'
                            : '${p.entries.length} brani',
                      ),
                      onTap: () => setState(() => _opened = p.id),
                      trailing: PopupMenuButton<String>(
                        tooltip: 'Opzioni playlist',
                        onSelected: (action) => _menu(p, action),
                        itemBuilder:
                            (_) => [
                              const PopupMenuItem(
                                value: 'cover',
                                child: Text('Scegli copertina'),
                              ),
                              if (!p.isFavorites)
                                const PopupMenuItem(
                                  value: 'rename',
                                  child: Text('Rinomina'),
                                ),
                              if (!p.isFavorites)
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Elimina'),
                                ),
                            ],
                      ),
                    );
                  },
                ),
      );
    },
  );

  Widget _tracks(Playlist playlist) {
    final entries = playlist.entries;
    final library = widget.library;
    final queue =
        entries.map((e) => library.find(e.songId)).whereType<Song>().toList();
    return ReorderableListView.builder(
      itemCount: entries.length,
      buildDefaultDragHandles: false,
      onReorder: (from, to) {
        final before = to == entries.length ? null : entries[to].songId;
        editPlaylist(
          context,
          () => widget.store.move(playlist.id, entries[from].songId, before),
        );
      },
      itemBuilder: (_, i) {
        final entry = entries[i];
        final song = library.find(entry.songId);
        return SwipeRemove(
          key: ValueKey(entry.songId),
          label: 'Rimuovi dalla playlist',
          onRemove:
              () => editPlaylist(
                context,
                () => widget.store.remove(playlist.id, entry.songId),
              ),
          child: ListTile(
            leading: Artwork(song?.cover),
            title: Text(song?.title ?? entry.title),
            subtitle: Text(song?.artist ?? '${entry.artist} · Non disponibile'),
            selected: song != null && song.id == widget.currentId,
            onTap: song == null ? null : () => widget.onSelect(queue, song),
            trailing: ReorderableDragStartListener(
              index: i,
              child: const Tooltip(
                message: 'Trascina per riordinare',
                child: SizedBox.square(dimension: 48, child: Icon(Icons.menu)),
              ),
            ),
          ),
        );
      },
    );
  }
}
