import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:void_tracks/data/downloads.dart';
import 'package:void_tracks/models/song.dart';
import 'package:void_tracks/screens/catalog_screen.dart';

class _Downloads extends ChangeNotifier implements Downloads {
  final saved = <String>[];
  @override
  Future<void> linkLegacy(List<Song> catalog) async {}
  @override
  DownloadStatus status(Song song) => DownloadStatus.available;
  @override
  Future<void> save(Song song) async => saved.add(song.id);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets(
    'Il catalogo permette di riprovare, cercare e ascoltare prima del download',
    (tester) async {
      final downloads = _Downloads();
      final song = Song(
        id: '1',
        title: 'Brano',
        artist: 'Artista, Ospite',
        album: '',
        audio: Uri.parse('https://music.example/1.mp3'),
        cover: Uri.parse('https://cover.example/1.jpg'),
        updatedAt: '1',
      );
      var attempts = 0;
      Song? playing;
      await tester.pumpWidget(
        MaterialApp(
          home: CatalogScreen(
            downloads: downloads,
            load: () async {
              if (attempts++ == 0) throw StateError('offline');
              return [song];
            },
            onSelect: (queue, selected) {
              expect(queue, [song]);
              playing = selected;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Riprova'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'ospite');
      await tester.tap(find.byTooltip('Riproduci'));
      expect(playing?.audio.scheme, 'https');
      expect(downloads.saved, isEmpty);
      await tester.tap(find.byTooltip('Scarica'));
      await tester.pumpAndSettle();
      expect(downloads.saved, ['1']);
    },
  );
}
