import 'package:isar/isar.dart';

import 'song.dart';

part 'playlist.g.dart';

@collection
class Playlist {
  static const favoritesId = -1;
  Id id = Isar.autoIncrement;
  late String name;
  List<byte>? coverBytes;

  @ignore
  bool get isFavorites => id == favoritesId;
  List<PlaylistEntry> entries = [];
}

@embedded
class PlaylistEntry {
  late String songId;
  late String title;
  late String artist;

  static PlaylistEntry fromSong(Song song) =>
      PlaylistEntry()
        ..songId = song.libraryId
        ..title = song.title
        ..artist = song.artist;
}
