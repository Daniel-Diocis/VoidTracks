import 'package:flutter/material.dart';

import '../models/song.dart';
import 'artwork.dart';

class SongList extends StatefulWidget {
  const SongList({
    super.key,
    required this.songs,
    required this.emptyMessage,
    required this.onSelect,
    required this.action,
    this.currentId,
    this.playing = false,
  });
  final List<Song> songs;
  final String emptyMessage;
  final String? currentId;
  final bool playing;
  final void Function(List<Song>, Song) onSelect;
  final Widget Function(Song) action;

  @override
  State<SongList> createState() => _SongListState();
}

class _SongListState extends State<SongList> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    if (widget.songs.isEmpty) {
      return Center(
        child: Text(widget.emptyMessage, textAlign: TextAlign.center),
      );
    }
    final visible = widget.songs.where((s) => s.matches(_query)).toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Cerca per titolo, artista o album',
            ),
            onChanged:
                (text) => setState(() => _query = text.trim().toLowerCase()),
          ),
        ),
        Expanded(
          child:
              visible.isEmpty
                  ? const Center(child: Text('Nessun risultato'))
                  : ListView.builder(
                    itemCount: visible.length,
                    itemBuilder: (_, i) {
                      final song = visible[i];
                      final selected = widget.currentId == song.id;
                      return ListTile(
                        key: ValueKey(song.id),
                        selected: selected,
                        leading: Artwork(song.cover),
                        title: Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          song.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => widget.onSelect(visible, song),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            widget.action(song),
                            IconButton(
                              tooltip:
                                  selected && widget.playing
                                      ? 'Pausa'
                                      : 'Riproduci',
                              icon: Icon(
                                selected && widget.playing
                                    ? Icons.pause
                                    : Icons.play_arrow,
                              ),
                              onPressed: () => widget.onSelect(visible, song),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
        ),
      ],
    );
  }
}
