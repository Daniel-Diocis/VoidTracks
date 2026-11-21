import 'package:flutter/material.dart';

import '../data/downloads.dart';
import '../models/song.dart';
import '../widgets/song_list.dart';

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({
    super.key,
    required this.downloads,
    required this.onSelect,
    required this.onOpenSettings,
    this.currentId,
  });
  final Downloads downloads;
  final void Function(List<Song>, Song) onSelect;
  final VoidCallback onOpenSettings;
  final String? currentId;

  Future<void> _remove(BuildContext context, Song song) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Rimuovere il download?'),
            content: Text(song.title),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Annulla'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Rimuovi'),
              ),
            ],
          ),
    );
    if (confirmed != true) return;
    try {
      await downloads.remove(song);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rimozione del download non riuscita.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Download'),
      actions: [
        IconButton(
          tooltip: 'Impostazioni',
          icon: const Icon(Icons.settings_outlined),
          onPressed: onOpenSettings,
        ),
      ],
    ),
    body: ListenableBuilder(
      listenable: downloads,
      builder:
          (_, __) => SongList(
            songs: downloads.songs,
            emptyMessage: 'I brani che scarichi appariranno qui.',
            onSelect: onSelect,
            currentId: currentId,
            action:
                (song) => IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Rimuovi download',
                  onPressed: () => _remove(context, song),
                ),
          ),
    ),
  );
}
