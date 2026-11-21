import 'package:isar/isar.dart';

part 'track.g.dart';

/// Download salvato sul dispositivo. I nomi dei campi Isar preservano i download della prima versione.
@collection
class Track {
  Id id = Isar.autoIncrement;
  String? remoteId;
  late String titolo;
  late String artista;
  late String album;
  @Name('music_path')
  late String musicPath;
  @Name('cover_path')
  late String coverPath;
  @Name('duration_ms')
  int? durationMs;
  @Name('updated_at')
  late String updatedAt;
}
