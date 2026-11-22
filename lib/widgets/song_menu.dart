import 'package:flutter/material.dart';

import '../data/downloads.dart';
import '../data/playlists.dart';
import '../models/playlist.dart';
import '../models/song.dart';
import 'artwork.dart';
import 'playlist_dialogs.dart';

Future<void> showSongMenu(
  BuildContext context,
  Song song, {
  required Playlists playlists,
  required PlaylistLibrary library,
  required Downloads downloads,
  required Song? cloudSong,
}) async {
  final save = await showModalBottomSheet<bool>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder:
        (_) => _SongMenu(
          song: song,
          playlists: playlists,
          library: library,
          downloads: downloads,
          cloudSong: cloudSong,
        ),
  );
  if (save == true && context.mounted) {
    await addSongToPlaylist(context, song, playlists, library);
  }
}

class _SongMenu extends StatefulWidget {
  const _SongMenu({
    required this.song,
    required this.playlists,
    required this.library,
    required this.downloads,
    required this.cloudSong,
  });
  final Song song;
  final Song? cloudSong;
  final Playlists playlists;
  final PlaylistLibrary library;
  final Downloads downloads;
  @override
  State<_SongMenu> createState() => _SongMenuState();
}

class _SongMenuState extends State<_SongMenu> {
  late final _favorites = widget.playlists.watchFavorites();
  bool _saving = false;

  Future<void> _download(Song song) async {
    setState(() => _saving = true);
    try {
      await widget.downloads.save(song);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Download fallito. Riprova.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final song = widget.song;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Artwork(song.cover),
              title: Text(
                song.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              subtitle: Text(song.artist),
              trailing: StreamBuilder<Playlist?>(
                stream: _favorites,
                builder: (_, snapshot) {
                  final added =
                      snapshot.data?.entries.any(
                        (e) =>
                            widget.library.canonicalId(e.songId) ==
                            song.libraryId,
                      ) ==
                      true;
                  return IconButton(
                    tooltip:
                        added
                            ? 'Rimuovi dai preferiti'
                            : 'Aggiungi ai preferiti',
                    style:
                        added
                            ? IconButton.styleFrom(
                              backgroundColor: const Color(0xff93435a),
                              foregroundColor: Colors.white,
                            )
                            : null,
                    icon: Icon(added ? Icons.favorite : Icons.favorite_border),
                    onPressed:
                        !snapshot.hasData
                            ? null
                            : () => editPlaylist(
                              context,
                              () => widget.playlists.setFavorite(
                                song,
                                widget.library,
                                selected: !added,
                              ),
                            ),
                  );
                },
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.playlist_add),
              title: const Text('Salva in una playlist'),
              onTap: () => Navigator.pop(context, true),
            ),
            ListenableBuilder(
              listenable: widget.downloads,
              builder: (_, __) {
                final cloud = widget.cloudSong;
                final status =
                    cloud == null
                        ? DownloadStatus.saved
                        : widget.downloads.status(cloud);
                final label = switch (status) {
                  DownloadStatus.available => 'Scarica',
                  DownloadStatus.update => 'Aggiorna download',
                  DownloadStatus.saved => 'Salvato offline',
                };
                return ListTile(
                  leading:
                      _saving
                          ? const SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : Icon(
                            status == DownloadStatus.saved
                                ? Icons.offline_pin
                                : Icons.download,
                          ),
                  title: Text(_saving ? 'Download in corso…' : label),
                  enabled:
                      cloud != null &&
                      status != DownloadStatus.saved &&
                      !_saving,
                  onTap: cloud == null ? null : () => _download(cloud),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
