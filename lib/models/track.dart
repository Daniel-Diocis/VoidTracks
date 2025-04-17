import 'package:isar/isar.dart';

part 'track.g.dart';

@collection
class Track {
  Id id = Isar.autoIncrement; // ID automatico

  late String title;
  late String artist;
  late String album;
  late String path;
  String? cover;
  int? durationMs; // opzionale, per salvare durata in millisecondi

  Track();
}
