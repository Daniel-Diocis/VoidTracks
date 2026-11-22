import 'package:isar/isar.dart';

import '../models/playlist.dart';
import '../models/song.dart';

/// Playlist entries keep a stable song ID; file paths are resolved at playback.
class PlaylistLibrary {
  PlaylistLibrary(List<Song> catalog, Iterable<Song> downloads) {
    for (final song in [...catalog, ...downloads]) {
      _byId[song.libraryId] = song;
      _byId[song.id] = song;
    }
  }

  final _byId = <String, Song>{};
  Song? find(String id) => _byId[id];
  String canonicalId(String id) => find(id)?.libraryId ?? id;
  List<Song> get songs => _byId.values.toSet().toList()..sort(Song.compare);
}

class Playlists {
  Playlists(this.db);
  final Isar db;

  Future<void> initialize() => db.writeTxn(() async {
    if (await db.playlists.get(Playlist.favoritesId) == null) {
      await db.playlists.put(
        Playlist()
          ..id = Playlist.favoritesId
          ..name = 'Brani preferiti',
      );
    }
  });

  Stream<Playlist?> watchFavorites() =>
      db.playlists.watchObject(Playlist.favoritesId, fireImmediately: true);

  Future<void> setFavorite(
    Song song,
    PlaylistLibrary library, {
    required bool selected,
  }) => _edit(Playlist.favoritesId, (playlist) {
    final remaining =
        playlist.entries
            .where((e) => library.canonicalId(e.songId) != song.libraryId)
            .toList();
    if (selected && remaining.length == playlist.entries.length) {
      playlist.entries = [...remaining, PlaylistEntry.fromSong(song)];
    } else if (!selected) {
      playlist.entries = remaining;
    }
  });

  Future<void> setCover(int id, List<int> bytes) =>
      _edit(id, (p) => p.coverBytes = bytes);

  Stream<List<Playlist>> watch() =>
      db.playlists.where().watch(fireImmediately: true);

  Future<int> create(String name, {Song? firstSong}) => db.writeTxn(() {
    final playlist = Playlist()..name = _name(name);
    if (firstSong != null) {
      playlist.entries = [PlaylistEntry.fromSong(firstSong)];
    }
    return db.playlists.put(playlist);
  });

  String _name(String name) {
    final value = name.trim();
    if (value.isEmpty) throw ArgumentError('Nome playlist vuoto');
    return value;
  }

  Future<void> _edit(int id, void Function(Playlist) edit) =>
      db.writeTxn(() async {
        final playlist = await db.playlists.get(id);
        if (playlist == null) throw StateError('Playlist eliminata');
        edit(playlist);
        await db.playlists.put(playlist);
      });

  Future<void> rename(int id, String name) => _edit(id, (p) {
    if (p.isFavorites) throw StateError('Playlist predefinita');
    p.name = _name(name);
  });
  Future<void> delete(int id) => db.writeTxn(() async {
    if (id == Playlist.favoritesId) throw StateError('Playlist predefinita');
    await db.playlists.delete(id);
  });

  Future<void> add(int id, Iterable<Song> songs, PlaylistLibrary library) =>
      _edit(id, (p) {
        final keys =
            p.entries.map((e) => library.canonicalId(e.songId)).toSet();
        p.entries = [
          ...p.entries,
          for (final song in songs)
            if (keys.add(song.libraryId)) PlaylistEntry.fromSong(song),
        ];
      });

  Future<void> remove(int id, String songId) => _edit(id, (p) {
    p.entries = p.entries.where((e) => e.songId != songId).toList();
  });

  Future<void> move(int id, String songId, String? beforeId) => _edit(id, (p) {
    final entries = List.of(p.entries);
    final from = entries.indexWhere((e) => e.songId == songId);
    if (from < 0 || songId == beforeId) return;
    final entry = entries.removeAt(from);
    final to = entries.indexWhere((e) => e.songId == beforeId);
    entries.insert(to < 0 ? entries.length : to, entry);
    p.entries = entries;
  });
}
