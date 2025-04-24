import 'package:isar/isar.dart';

part 'track.g.dart';

@collection
class Track {
  Id id = Isar.autoIncrement;

  late String titolo;
  late String artista;
  late String album;
  late String music_path;
  late String cover_path;
  int? duration_ms;
  late String updated_at;

  Track();

  factory Track.fromSupabase(Map<String, dynamic> brano) {
    return Track()
      ..titolo = brano['titolo']
      ..artista = brano['artista']
      ..album = brano['album']
      ..music_path = brano['music_path']
      ..cover_path = brano['cover_path']
      ..updated_at = brano['updated_at'];
  }

  Map<String, dynamic> toMap() {
    return {
      'titolo': titolo,
      'artista': artista,
      'album': album,
      'music_path': music_path,
      'cover_path': cover_path,
      'duration_ms': duration_ms,
      'updated_at': updated_at,
    };
  }
}