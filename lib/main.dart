import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'data/catalog.dart';
import 'data/downloads.dart';
import 'data/playlists.dart';
import 'models/playlist.dart';
import 'models/track.dart';
import 'playback/playback.dart';
import 'settings/theme_preference.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: 'assets/.env');
  await Supabase.initialize(
    url: dotenv.get('SUPABASE_URL'),
    anonKey: dotenv.get('SUPABASE_ANON_KEY'),
  );
  final documents = await getApplicationDocumentsDirectory();
  final db = await Isar.open([
    TrackSchema,
    PlaylistSchema,
  ], directory: documents.path);
  final playlists = Playlists(db);
  await playlists.initialize();
  final downloads = Downloads(db, documents, http.Client());
  await downloads.initialize();
  final playback = await AudioService.init(
    builder: () => Playback(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.tuaapp.channel.audio',
      androidNotificationChannelName: 'Riproduzione audio',
      androidNotificationIcon: 'drawable/ic_notification',
    ),
  );
  await (await AudioSession.instance).configure(
    const AudioSessionConfiguration.music(),
  );
  await playback.initialize();
  final catalog = Catalog(
    Supabase.instance.client,
    Uri.parse(dotenv.get('MUSIC_URL')),
    Uri.parse(dotenv.get('COVER_URL')),
  );
  runApp(
    VoidTracksApp(
      catalog: catalog,
      downloads: downloads,
      playlists: playlists,
      playback: playback,
      themePreference: ThemePreference(await SharedPreferences.getInstance()),
    ),
  );
}
