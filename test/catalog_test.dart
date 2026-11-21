import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:void_tracks/data/catalog.dart';

void main() {
  test(
    'Il catalogo legge solo metadati, pagina per ID e conserva le chiavi R2',
    () async {
      final offsets = <int>[];
      final client = SupabaseClient(
        'https://db.example',
        'anon',
        httpClient: MockClient((request) async {
          expect(request.url.path, '/rest/v1/brani');
          final offset = int.parse(request.url.queryParameters['offset']!);
          offsets.add(offset);
          final rows = List.generate(
            offset == 0 ? 200 : 1,
            (i) => {
              'id': '${offset + i}',
              'titolo': 'Brano',
              'artista': offset == 0 ? 'B, Ospite' : 'A',
              'album': null,
              'music_path': "folder/Città #1 + O'Neil.mp3",
              'cover_path': 'foto.jpg',
              'updated_at': '1',
            },
          );
          return http.Response.bytes(
            utf8.encode(jsonEncode(rows)),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      addTearDown(client.dispose);
      final songs =
          await Catalog(
            client,
            Uri.parse('https://music.example/bucket/'),
            Uri.parse('https://cover.example'),
          ).load();
      expect(offsets, [0, 200]);
      expect(songs.length, 201);
      expect(songs.first.id, '200');
      expect(songs.first.album, '');
      expect(songs.first.audio.pathSegments, [
        'bucket',
        'folder',
        "Città #1 + O'Neil.mp3",
      ]);
      expect(songs.first.audio.fragment, isEmpty);
    },
  );
}
