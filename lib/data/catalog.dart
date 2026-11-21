import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/song.dart';

class Catalog {
  Catalog(this.client, this.musicBase, this.coverBase);

  final SupabaseClient client;
  final Uri musicBase;
  final Uri coverBase;

  static Uri objectUri(Uri base, String key) => base.replace(
    pathSegments: [
      ...base.pathSegments.where((segment) => segment.isNotEmpty),
      ...key.split('/'),
    ],
  );

  Future<List<Song>> load() async {
    const pageSize = 200;
    final songs = <String, Song>{};
    var offset = 0;
    while (true) {
      final rows = await client
          .from('brani')
          .select('id,titolo,artista,album,music_path,cover_path,updated_at')
          .order('id')
          .range(offset, offset + pageSize - 1);
      for (final row in rows) {
        final song = Song(
          id: row['id'] as String,
          title: row['titolo'] as String,
          artist: row['artista'] as String,
          album: row['album'] as String? ?? '',
          audio: objectUri(musicBase, row['music_path'] as String),
          cover: objectUri(coverBase, row['cover_path'] as String),
          updatedAt: row['updated_at'] as String,
        );
        songs[song.id] = song;
      }
      if (rows.length < pageSize) break;
      offset += rows.length;
    }
    return songs.values.toList()..sort(Song.compare);
  }
}
