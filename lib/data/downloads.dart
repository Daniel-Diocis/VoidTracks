import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:isar/isar.dart';

import '../models/song.dart';
import '../models/track.dart';

enum DownloadStatus { available, saved, update }

class Downloads extends ChangeNotifier {
  Downloads(this.db, this.documents, this.client);

  final Isar db;
  final Directory documents;
  final http.Client client;
  List<Song> _songs = [];
  Map<String, Track> _byRemoteId = {};
  Future<void> _pending = Future.value();

  List<Song> get songs => _songs;
  final _incomplete = <int>{};
  Iterable<Song> get playableSongs => _songs.where(
    (song) => !_incomplete.contains(int.parse(song.id.substring(6))),
  );

  DownloadStatus status(Song song) {
    final row = _byRemoteId[song.id];
    if (row == null) return DownloadStatus.available;
    if (row.updatedAt != song.updatedAt || _incomplete.contains(row.id)) {
      return DownloadStatus.update;
    }
    return DownloadStatus.saved;
  }

  // Gli aggiornamenti di file e database devono terminare nello stesso ordine.
  Future<void> _serialize(Future<void> Function() action) {
    final operation = _pending.then((_) => action());
    _pending = operation.catchError((Object _) {});
    return operation;
  }

  // Le vecchie versioni salvavano percorsi assoluti nella radice Documents.
  // Su iOS la radice del container può cambiare dopo un aggiornamento.
  String _relative(String path) =>
      path.startsWith('/') ? path.split('/').last : path;
  File _file(String path) => File('${documents.path}/${_relative(path)}');

  Future<void> initialize() async {
    final rows = await db.tracks.where().findAll();
    rows.sort((a, b) {
      final date = b.updatedAt.compareTo(a.updatedAt);
      return date != 0 ? date : b.id.compareTo(a.id);
    });
    final seen = <String>{};
    final duplicates = <int>[];
    for (final row in rows) {
      if (row.remoteId == null && !seen.add(_relative(row.musicPath))) {
        duplicates.add(row.id);
      }
    }
    if (duplicates.isNotEmpty) {
      await db.writeTxn(() => db.tracks.deleteAll(duplicates));
    }
    await _reload();
    await _recoverFiles();
  }

  // Un arresto tra la scrittura dei file e il commit Isar può lasciare una
  // revisione isolata. La vecchia cache nella radice Documents non è nostra.
  Future<void> _recoverFiles() async {
    final root = Directory('${documents.path}/downloads');
    if (!await root.exists()) return;
    final inUse = {
      for (final song in _songs) File.fromUri(song.audio).parent.path,
    };
    await for (final entry in root.list(followLinks: false)) {
      if (entry is! Directory ||
          inUse.contains(entry.path) ||
          !entry.path.startsWith('${root.path}/track-')) {
        continue;
      }
      for (final name in ['audio.mp3', 'cover.jpg']) {
        final file = File('${entry.path}/$name');
        if (await file.exists()) await file.delete();
      }
      if (await entry.list().isEmpty) await entry.delete();
    }
  }

  Future<void> _reload() async {
    final rows = await db.tracks.where().findAll();
    _incomplete.clear();
    for (final row in rows) {
      if (!await _file(row.musicPath).exists() ||
          !await _file(row.coverPath).exists()) {
        _incomplete.add(row.id);
      }
    }
    _byRemoteId = {
      for (final row in rows)
        if (row.remoteId != null) row.remoteId!: row,
    };
    _songs = List.unmodifiable(
      rows
          .map(
            (row) => Song(
              id: 'local:${row.id}',
              remoteId: row.remoteId,
              title: row.titolo,
              artist: row.artista,
              album: row.album,
              updatedAt: row.updatedAt,
              audio: _file(row.musicPath).uri,
              cover: _file(row.coverPath).uri,
            ),
          )
          .toList()
        ..sort(Song.compare),
    );
    notifyListeners();
  }

  Future<void> linkLegacy(List<Song> catalog) => _serialize(() async {
    // I vecchi download conservano soltanto il nome del file remoto.
    // Se due oggetti hanno lo stesso nome, il collegamento resta indeterminato.
    final rows = await db.tracks.filter().remoteIdIsNull().findAll();
    if (rows.isEmpty) return;
    final byName = <String, List<Song>>{};
    for (final song in catalog) {
      byName.putIfAbsent(song.audio.pathSegments.last, () => []).add(song);
    }
    final changes = <Track>[];
    for (final row in rows) {
      final candidates = byName[_relative(row.musicPath)];
      if (candidates == null || candidates.length != 1) continue;
      final id = candidates.single.id;
      if (_byRemoteId.containsKey(id)) continue;
      row.remoteId = id;
      changes.add(row);
    }
    if (changes.isEmpty) return;
    await db.writeTxn(() => db.tracks.putAll(changes));
    await _reload();
  });

  Future<void> _fetch(Uri uri, File destination) async {
    final response = await client.send(http.Request('GET', uri));
    if (response.statusCode != 200) {
      await response.stream.drain<void>();
      throw HttpException(
        'Download fallito (HTTP ${response.statusCode})',
        uri: uri,
      );
    }
    await response.stream.pipe(destination.openWrite());
    final size = await destination.length();
    if (size == 0 ||
        (response.contentLength != null && size != response.contentLength)) {
      throw const FileSystemException('File incompleto');
    }
  }

  Future<void> save(Song song) => _serialize(() async {
    final previous = _byRemoteId[song.id];
    if (previous != null &&
        previous.updatedAt == song.updatedAt &&
        await _file(previous.musicPath).exists() &&
        await _file(previous.coverPath).exists()) {
      return;
    }

    final root = await Directory(
      '${documents.path}/downloads',
    ).create(recursive: true);
    // La vecchia versione rimane leggibile fino al commit della nuova coppia.
    final revision = await root.createTemp('track-');
    final base =
        'downloads/${revision.uri.pathSegments.where((s) => s.isNotEmpty).last}';
    final next =
        Track()
          ..id = previous?.id ?? Isar.autoIncrement
          ..remoteId = song.id
          ..titolo = song.title
          ..artista = song.artist
          ..album = song.album
          ..musicPath = '$base/audio.mp3'
          ..coverPath = '$base/cover.jpg'
          ..updatedAt = song.updatedAt;
    try {
      await _fetch(song.audio, _file(next.musicPath));
      await _fetch(song.cover, _file(next.coverPath));
      await db.writeTxn(() => db.tracks.put(next));
    } catch (_) {
      await revision.delete(recursive: true);
      rethrow;
    }
    await _reload();
    if (previous != null) await _removeUnreferenced(previous);
  });

  Future<void> remove(Song local) => _serialize(() async {
    final id = int.parse(local.id.substring('local:'.length));
    final row = await db.tracks.get(id);
    if (row == null) return;
    await db.writeTxn(() => db.tracks.delete(id));
    await _reload();
    await _removeUnreferenced(row);
  });

  Future<void> _removeUnreferenced(Track old) async {
    final referenced = {
      for (final song in _songs) ...[song.audio, song.cover],
    };
    for (final path in {old.musicPath, old.coverPath}) {
      final file = _file(path);
      if (!referenced.contains(file.uri) && await file.exists()) {
        await file.delete();
      }
    }
    if (old.musicPath.startsWith('downloads/track-')) {
      final dir = _file(old.musicPath).parent;
      if (await dir.exists() && await dir.list().isEmpty) await dir.delete();
    }
  }

  @override
  void dispose() {
    client.close();
    super.dispose();
  }
}
