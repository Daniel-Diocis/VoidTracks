import 'package:isar/isar.dart';

import 'song.dart';

part 'playlist.g.dart';

@collection
class Playlist {
  Id id = Isar.autoIncrement;
  late String name;
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
