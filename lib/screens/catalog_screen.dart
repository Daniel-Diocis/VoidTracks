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
    required this.onSongMenu,
    required this.onOpenSettings,
    this.currentId,
  });
  final Future<List<Song>> Function() load;
  final Downloads downloads;
  final void Function(List<Song>, Song) onSelect;
  final ValueChanged<Song> onSongMenu;
  final VoidCallback onOpenSettings;
  final String? currentId;

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  List<Song> _songs = [];
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
                  : SongList(
                    songs: _songs,
                    emptyMessage: 'Il catalogo è vuoto',
                    onSelect: widget.onSelect,
                    onSongMenu: widget.onSongMenu,
                    currentId: widget.currentId,
                  ),
        ),
      ],
    ),
  );
}
