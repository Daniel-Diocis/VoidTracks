import 'dart:async';

import 'package:flutter/material.dart';

import 'data/catalog.dart';
import 'data/downloads.dart';
import 'data/playlists.dart';
import 'models/song.dart';
import 'screens/playlists_screen.dart';
import 'widgets/song_menu.dart';
import 'playback/playback.dart';
import 'screens/catalog_screen.dart';
import 'screens/downloads_screen.dart';
import 'screens/now_playing_screen.dart';
import 'screens/settings_screen.dart';
import 'settings/theme_preference.dart';
import 'widgets/player_controls.dart';

class VoidTracksApp extends StatefulWidget {
  const VoidTracksApp({
    super.key,
    required this.catalog,
    required this.playlists,
    required this.downloads,
    required this.playback,
    required this.themePreference,
  });
  final Catalog catalog;
  final Playlists playlists;
  final Downloads downloads;
  final Playback playback;
  final ThemePreference themePreference;

  @override
  State<VoidTracksApp> createState() => _VoidTracksAppState();
}

class _VoidTracksAppState extends State<VoidTracksApp> {
  int _tab = 0;
  List<Song> _catalog = [];
  late PlaylistLibrary _library;
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  late final StreamSubscription<Object> _errors;

  @override
  void initState() {
    super.initState();
    _library = PlaylistLibrary(_catalog, widget.downloads.playableSongs);
    widget.downloads.addListener(_downloadsChanged);
    _errors = widget.playback.errors.listen((error) {
      debugPrint('Riproduzione: $error');
      _messenger.currentState?.showSnackBar(
        const SnackBar(content: Text('Impossibile riprodurre il brano.')),
      );
    });
  }

  void _downloadsChanged() {
    setState(
      () =>
          _library = PlaylistLibrary(_catalog, widget.downloads.playableSongs),
    );
    widget.playback.refreshDownloads(widget.downloads.songs);
  }

  Future<List<Song>> _loadCatalog() async {
    final songs = await widget.catalog.load();
    if (mounted) {
      setState(() {
        _catalog = songs;
        _library = PlaylistLibrary(songs, widget.downloads.playableSongs);
      });
    }
    return songs;
  }

  void _songMenu(BuildContext context, Song song) {
    final cloud =
        song.audio.scheme == 'file'
            ? _catalog.where((s) => s.id == song.libraryId).firstOrNull
            : song;
    showSongMenu(
      context,
      song,
      playlists: widget.playlists,
      library: _library,
      downloads: widget.downloads,
      cloudSong: cloud,
    );
  }

  @override
  void dispose() {
    widget.downloads.removeListener(_downloadsChanged);
    _errors.cancel();
    widget.playback.dispose();
    widget.themePreference.dispose();
    widget.downloads.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playback = widget.playback;
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: widget.themePreference,
      builder:
          (_, mode, home) => MaterialApp(
            theme: appTheme(Brightness.light),
            darkTheme: appTheme(Brightness.dark),
            themeMode: mode,
            title: 'VoidTracks',
            scaffoldMessengerKey: _messenger,
            home: home,
          ),
      child: Builder(
        builder:
            (context) => Scaffold(
              body: CurrentItem(
                playback,
                (item) => IndexedStack(
                  index: _tab,
                  children: [
                    CatalogScreen(
                      load: _loadCatalog,
                      downloads: widget.downloads,
                      onSelect: playback.select,
                      onSongMenu: (song) => _songMenu(context, song),
                      onOpenSettings:
                          () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder:
                                  (_) => SettingsScreen(widget.themePreference),
                            ),
                          ),
                      currentId: item?.id,
                    ),
                    DownloadsScreen(
                      downloads: widget.downloads,
                      onSelect: playback.select,
                      onSongMenu: (song) => _songMenu(context, song),
                      onOpenSettings:
                          () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder:
                                  (_) => SettingsScreen(widget.themePreference),
                            ),
                          ),
                      currentId: item?.id,
                    ),
                    PlaylistsScreen(
                      store: widget.playlists,
                      library: _library,
                      onSelect: playback.select,
                      active: _tab == 2,
                      currentId: item?.id,
                    ),
                  ],
                ),
              ),
              bottomNavigationBar: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MiniPlayer(
                    playback,
                    onOpen:
                        () => NowPlayingScreen.show(
                          context,
                          playback,
                          onSongMenu: (id) {
                            final song =
                                playback.queuedSong(id) ?? _library.find(id);
                            if (song != null) _songMenu(context, song);
                          },
                        ),
                  ),
                  NavigationBar(
                    selectedIndex: _tab,
                    onDestinationSelected: (i) => setState(() => _tab = i),
                    destinations: const [
                      NavigationDestination(
                        icon: Icon(Icons.cloud_outlined),
                        label: 'Catalogo',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.download_for_offline_outlined),
                        label: 'Download',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.queue_music),
                        label: 'Playlist',
                      ),
                    ],
                  ),
                ],
              ),
            ),
      ),
    );
  }
}
