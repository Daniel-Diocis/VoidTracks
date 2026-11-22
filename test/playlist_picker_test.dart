import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:void_tracks/data/playlists.dart';
import 'package:void_tracks/models/playlist.dart';
import 'package:void_tracks/models/song.dart';
import 'package:void_tracks/widgets/playlist_dialogs.dart';

void main() {
  testWidgets(
    'La selezione resta attiva durante la ricerca ed esclude i duplicati',
    (tester) async {
      Song song(String name) => Song(
        id: name,
        title: name,
        artist: 'Artista',
        album: '',
        audio: Uri.https('music.example', name),
        cover: Uri.https('cover.example', name),
        updatedAt: '1',
      );
      final songs = ['Uno', 'Due', 'Tre'].map(song).toList();
      final playlist =
          Playlist()
            ..name = 'Viaggio'
            ..entries = [PlaylistEntry.fromSong(songs.first)];
      List<Song>? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder:
                (context) => TextButton(
                  onPressed: () async {
                    selected = await Navigator.push<List<Song>>(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) => PlaylistSongPicker(
                              playlist: playlist,
                              library: PlaylistLibrary(songs, []),
                            ),
                      ),
                    );
                  },
                  child: const Text('Apri'),
                ),
          ),
        ),
      );
      await tester.tap(find.text('Apri'));
      await tester.pumpAndSettle();
      final existing = tester.widget<CheckboxListTile>(
        find.widgetWithText(CheckboxListTile, 'Uno'),
      );
      expect(existing.onChanged, isNull);
      await tester.tap(find.text('Due'));
      await tester.enterText(find.byType(TextField), 'Tre');
      await tester.pump();
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Tre'));
      await tester.pump();
      await tester.tap(find.text('Aggiungi (2)'));
      await tester.pumpAndSettle();
      expect(selected, [songs[1], songs[2]]);
    },
  );
}
