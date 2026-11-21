class Song {
  const Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.audio,
    required this.cover,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String artist;
  final String album;
  final Uri audio;
  final Uri cover;
  final String updatedAt;

  bool matches(String query) =>
      [title, artist, album].any((s) => s.toLowerCase().contains(query));

  static int compare(Song a, Song b) {
    String primary(Song song) =>
        song.artist.split(',').first.trim().toLowerCase();
    final byArtist = primary(a).compareTo(primary(b));
    return byArtist != 0
        ? byArtist
        : a.title.toLowerCase().compareTo(b.title.toLowerCase());
  }
}
