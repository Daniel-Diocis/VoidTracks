import 'dart:async';

import 'package:flutter/material.dart';

import 'data/catalog.dart';
import 'data/downloads.dart';
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
    required this.downloads,
    required this.playback,
    required this.themePreference,
  });
  final Catalog catalog;
  final Downloads downloads;
  final Playback playback;
  final ThemePreference themePreference;

  @override
  State<VoidTracksApp> createState() => _VoidTracksAppState();
}

class _VoidTracksAppState extends State<VoidTracksApp> {
  int _tab = 0;
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  late final StreamSubscription<Object> _errors;

  @override
  void initState() {
    super.initState();
    widget.downloads.addListener(_downloadsChanged);
    _errors = widget.playback.errors.listen((error) {
      debugPrint('Riproduzione: $error');
      _messenger.currentState?.showSnackBar(
        const SnackBar(content: Text('Impossibile riprodurre il brano.')),
      );
    });
  }

  void _downloadsChanged() =>
      widget.playback.refreshDownloads(widget.downloads.songs);

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
                      load: widget.catalog.load,
                      downloads: widget.downloads,
                      onSelect: playback.select,
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
                      onOpenSettings:
                          () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder:
                                  (_) => SettingsScreen(widget.themePreference),
                            ),
                          ),
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
                    onOpen: () => NowPlayingScreen.show(context, playback),
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
                    ],
                  ),
                ],
              ),
            ),
      ),
    );
  }
}
