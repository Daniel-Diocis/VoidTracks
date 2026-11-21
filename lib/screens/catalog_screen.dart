import 'package:flutter/material.dart';

import '../models/song.dart';
import '../data/downloads.dart';
import '../widgets/song_list.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({
    super.key,
    required this.load,
    required this.downloads,
    required this.onSelect,
    required this.onOpenSettings,
    this.currentId,
    this.playing = false,
  });
  final Future<List<Song>> Function() load;
  final Downloads downloads;
  final void Function(List<Song>, Song) onSelect;
  final VoidCallback onOpenSettings;
  final String? currentId;
  final bool playing;

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  List<Song> _songs = [];
  final _saving = <String>{};
  bool _loading = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final songs = await widget.load();
      if (!mounted) return;
      await widget.downloads.linkLegacy(songs);
      if (mounted) setState(() => _songs = songs);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save(Song song) async {
    if (_saving.contains(song.id)) return;
    setState(() => _saving.add(song.id));
    try {
      await widget.downloads.save(song);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download di “${song.title}” fallito. Riprova.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving.remove(song.id));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('VoidTracks'),
      actions: [
        IconButton(
          tooltip: 'Aggiorna catalogo',
          onPressed: _loading ? null : _refresh,
          icon: const Icon(Icons.refresh),
        ),
        IconButton(
          tooltip: 'Impostazioni',
          icon: const Icon(Icons.settings_outlined),
          onPressed: widget.onOpenSettings,
        ),
      ],
    ),
    body: Column(
      children: [
        if (_loading) const LinearProgressIndicator(),
        if (_failed)
          ListTile(
            title: const Text('Catalogo non disponibile'),
            trailing: TextButton(
              onPressed: _refresh,
              child: const Text('Riprova'),
            ),
          ),
        Expanded(
          child:
              _songs.isEmpty && (_loading || _failed)
                  ? const SizedBox.shrink()
                  : ListenableBuilder(
                    listenable: widget.downloads,
                    builder:
                        (_, __) => SongList(
                          songs: _songs,
                          emptyMessage: 'Il catalogo è vuoto',
                          onSelect: widget.onSelect,
                          currentId: widget.currentId,
                          playing: widget.playing,
                          action: (song) {
                            if (_saving.contains(song.id)) {
                              return const SizedBox.square(
                                dimension: 24,
                                child: CircularProgressIndicator(),
                              );
                            }
                            final status = widget.downloads.status(song);
                            final (label, icon) = switch (status) {
                              DownloadStatus.available => (
                                'Scarica',
                                Icons.download,
                              ),
                              DownloadStatus.update => (
                                'Aggiorna download',
                                Icons.system_update_alt,
                              ),
                              DownloadStatus.saved => (
                                'Salvato offline',
                                Icons.offline_pin,
                              ),
                            };
                            return IconButton(
                              tooltip: label,
                              icon: Icon(icon),
                              onPressed:
                                  status == DownloadStatus.saved
                                      ? null
                                      : () => _save(song),
                            );
                          },
                        ),
                  ),
        ),
      ],
    ),
  );
}
