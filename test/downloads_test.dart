import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:isar/isar.dart';
import 'package:void_tracks/data/downloads.dart';
import 'package:void_tracks/data/playlists.dart';
import 'package:void_tracks/models/playlist.dart';
import 'package:void_tracks/models/song.dart';
import 'package:void_tracks/models/track.dart';

void main() {
  late Directory dir;
  late Isar db;
  late Downloads downloads;
  late bool failCover;
  late List<Uri> requests;

  Song cloud(String version, {String file = 'A.mp3'}) => Song(
    id: 'uuid-a',
    title: 'A',
    artist: 'Artista',
    album: '',
    audio: Uri.https('music.example', file),
    cover: Uri.https('cover.example', 'album.jpg'),
    updatedAt: version,
  );

  setUpAll(() async {
    final config = File('.dart_tool/package_config.json');
    final packages =
        jsonDecode(await config.readAsString())['packages'] as List;
    final root = config.absolute.uri.resolve(
      packages.singleWhere((p) => p['name'] == 'isar_flutter_libs')['rootUri']
          as String,
    );
    final binary =
        Platform.isMacOS
            ? 'macos/libisar.dylib'
            : Platform.isWindows
            ? 'windows/isar.dll'
            : 'linux/libisar.so';
    await Isar.initializeIsarCore(
      libraries: {
        Abi.current():
            File.fromUri(Uri.parse('${root.toString()}/').resolve(binary)).path,
      },
    );
  });
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('voidtracks-test-');
    db = await Isar.open([TrackSchema], directory: dir.path, inspector: false);
    failCover = false;
    requests = [];
    downloads = Downloads(
      db,
      dir,
      MockClient((request) async {
        requests.add(request.url);
        if (failCover && request.url.host == 'cover.example') {
          return http.Response('missing', 404);
        }
        return http.Response.bytes([1, 2, 3], 200);
      }),
    );
  });
  tearDown(() async {
    downloads.dispose();
    await db.close();
    await dir.delete(recursive: true);
  });

  test(
    'Le playlist preservano i download esistenti, identità e ordine al riavvio',
    () async {
      final first = cloud('1');
      await downloads.save(first);
      final local = downloads.songs.single;
      expect(local.libraryId, first.id);

      // Open the same device database with the additional collection.
      await db.close();
      db = await Isar.open(
        [TrackSchema, PlaylistSchema],
        directory: dir.path,
        inspector: false,
      );
      expect(await db.tracks.count(), 1);
      var store = Playlists(db);
      final second = Song(
        id: 'uuid-b',
        title: 'B',
        artist: 'Artista',
        album: '',
        audio: Uri.https('music.example', 'B.mp3'),
        cover: first.cover,
        updatedAt: '1',
      );
      final library = PlaylistLibrary([first, second], [local]);
      expect(library.songs, [local, second]);
      final id = await store.create('  Viaggio  ', firstSong: first);
      await Future.wait([
        store.add(id, [local], library),
        store.add(id, [second], library),
      ]);
      await store.move(id, second.id, first.id);
      await store.rename(id, 'In viaggio');
      await db.close();
      db = await Isar.open(
        [TrackSchema, PlaylistSchema],
        directory: dir.path,
        inspector: false,
      );
      store = Playlists(db);
      final saved = (await store.watch().first).single;
      expect(saved.name, 'In viaggio');
      expect(saved.entries.map((e) => e.songId), [second.id, first.id]);
      expect(PlaylistLibrary([], [local]).find(first.id), local);
      expect(PlaylistLibrary([first], []).find(first.id), first);
      await store.remove(id, second.id);
      expect(
        (await store.watch().first).single.entries.single.songId,
        first.id,
      );
      await store.delete(id);
      expect(await store.watch().first, isEmpty);
      expect(await db.tracks.count(), 1);
      expect(await File.fromUri(local.audio).exists(), isTrue);
    },
  );

  test(
    'Il riavvio recupera i download interrotti e permette di riparare una copia incompleta',
    () async {
      await downloads.initialize();
      await downloads.save(cloud('1'));
      final original = downloads.songs.single;
      await File.fromUri(original.cover).delete();
      final interrupted =
          await Directory('${dir.path}/downloads/track-interrupted').create();
      await File('${interrupted.path}/audio.mp3').writeAsBytes([0]);
      await downloads.initialize();
      expect(downloads.status(cloud('1')), DownloadStatus.update);
      expect(await interrupted.exists(), isFalse);
      await downloads.save(cloud('1'));
      expect(downloads.songs.single.id, original.id);
      expect(downloads.status(cloud('1')), DownloadStatus.saved);
    },
  );

  test(
    'Scarica due volte, aggiorna e rimuovi mantengono una sola copia',
    () async {
      await downloads.initialize();
      await Future.wait([
        downloads.save(cloud('1')),
        downloads.save(cloud('1')),
      ]);
      expect(requests.length, 2);
      final first = downloads.songs.single;
      await downloads.save(cloud('2', file: 'nuovo.mp3'));
      final updated = downloads.songs.single;
      expect(updated.id, first.id);
      expect(updated.updatedAt, '2');
      expect(await File.fromUri(first.audio).exists(), isFalse);
      expect(await File.fromUri(updated.audio).readAsBytes(), [1, 2, 3]);
      await downloads.remove(updated);
      expect(await db.tracks.count(), 0);
      expect(await File.fromUri(updated.audio).exists(), isFalse);
      expect(await File.fromUri(updated.cover).exists(), isFalse);
    },
  );

  test(
    'Un errore sulla copertina conserva audio, copertina e versione precedenti',
    () async {
      await downloads.initialize();
      await downloads.save(cloud('1'));
      final first = downloads.songs.single;
      failCover = true;
      await expectLater(
        downloads.save(cloud('2')),
        throwsA(isA<HttpException>()),
      );
      expect(downloads.songs.single.audio, first.audio);
      expect(downloads.songs.single.updatedAt, '1');
      expect(await File.fromUri(first.audio).exists(), isTrue);
      expect(await File.fromUri(first.cover).exists(), isTrue);
      expect(await Directory('${dir.path}/downloads').list().length, 1);
      failCover = false;
      await downloads.save(cloud('2'));
      expect(downloads.songs.single.updatedAt, '2');
    },
  );

  test(
    'La vecchia libreria si apre offline e si collega senza riscaricare i file',
    () async {
      Track legacy(String file, String version) =>
          Track()
            ..titolo = file
            ..artista = 'Artista'
            ..album = 'Album'
            ..updatedAt = version
            ..musicPath = '/vecchio-container/Documents/$file'
            ..coverPath = '/vecchio-container/Documents/album.jpg';
      for (final file in ['A.mp3', 'B.mp3', 'album.jpg']) {
        await File('${dir.path}/$file').writeAsBytes([1]);
      }
      await db.writeTxn(
        () => db.tracks.putAll([
          legacy('A.mp3', '1'),
          legacy('A.mp3', '2'),
          legacy('B.mp3', '1'),
        ]),
      );
      await downloads.initialize();
      expect(downloads.songs.length, 2);
      final a = downloads.songs.firstWhere((s) => s.title == 'A.mp3');
      expect(a.updatedAt, '2');
      expect(await File.fromUri(a.audio).exists(), isTrue);
      await downloads.linkLegacy([cloud('2')]);
      expect(downloads.status(cloud('2')), DownloadStatus.saved);
      await downloads.save(cloud('2'));
      expect(requests, isEmpty);
      await downloads.remove(a);
      expect(await File.fromUri(a.cover).exists(), isTrue);
      expect(await File.fromUri(downloads.songs.single.audio).exists(), isTrue);
    },
  );
}
