import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:void_tracks/playback/playback.dart';
import 'package:void_tracks/widgets/player_controls.dart';
import 'package:void_tracks/screens/now_playing_screen.dart';
import 'package:void_tracks/widgets/artwork.dart';

class _Player extends Fake implements AudioPlayer {
  @override
  Duration position = const Duration(seconds: 3);
  @override
  bool hasPrevious = true;
  @override
  Duration get duration => const Duration(minutes: 4);
  @override
  Stream<Duration?> get durationStream => const Stream.empty();
  @override
  Stream<Duration> get positionStream => const Stream.empty();
  int previousCalls = 0;
  @override
  bool get playing => false;
  @override
  Stream<bool> get playingStream => const Stream.empty();
  @override
  Stream<PlaybackEvent> get playbackEventStream => const Stream.empty();
  @override
  Stream<SequenceState?> get sequenceStateStream => const Stream.empty();
  @override
  SequenceState get sequenceState => SequenceState(
    [
      AudioSource.uri(
        Uri.file('/song.mp3'),
        tag: const MediaItem(
          id: '1',
          title: 'Un titolo molto lungo per il mini-player',
          artist: 'Artista',
        ),
      ),
    ],
    0,
    [0],
    false,
    LoopMode.all,
  );

  @override
  Future<void> seek(Duration? position, {int? index}) async {
    this.position = position!;
  }

  @override
  Future<void> seekToPrevious() async {
    previousCalls++;
  }

  @override
  Future<void> dispose() async {}
}

class _Controls extends Fake implements Playback {
  @override
  final player = _Player();
  int previousCalls = 0;

  @override
  Future<void> previous() async {
    previousCalls++;
  }

  @override
  Future<void> toggle() async {}

  @override
  Future<void> seek(Duration position) => player.seek(position);

  @override
  Future<void> next() async {}
}

void main() {
  test(
    'Precedente ricomincia da tre secondi o se manca una traccia precedente',
    () async {
      final audio = _Player();
      final playback = Playback(audioPlayer: audio);
      addTearDown(playback.dispose);
      await playback.previous();
      expect(audio.position, Duration.zero);
      expect(audio.previousCalls, 0);
      await playback.previous();
      expect(audio.previousCalls, 1);
      audio.hasPrevious = false;
      audio.position = const Duration(seconds: 1);
      await playback.previous();
      expect(audio.position, Duration.zero);
      expect(audio.previousCalls, 1);
    },
  );

  testWidgets('Il mini-player mostra il comando precedente anche a 320 punti', (
    tester,
  ) async {
    final playback = _Controls();
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: MiniPlayer(playback, onOpen: () => opened = true),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    final previous = find.byIcon(Icons.skip_previous);
    expect(
      tester.getCenter(previous).dx,
      lessThan(tester.getCenter(find.byIcon(Icons.play_arrow_rounded)).dx),
    );
    await tester.tap(previous);
    expect(playback.previousCalls, 1);
    expect(opened, isFalse);
    await tester.tap(find.text('Artista'));
    expect(opened, isTrue);
  });
  testWidgets('Slider, trascinamento e freccia del player', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final playback = _Controls();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder:
              (context) => TextButton(
                onPressed: () => NowPlayingScreen.show(context, playback),
                child: const Text('Apri player'),
              ),
        ),
      ),
    );
    Future<void> open() async {
      await tester.tap(find.text('Apri player'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Riduci player'), findsOneWidget);
    }

    await open();
    final slider = find.byType(Slider);
    await tester.drag(slider, const Offset(60, 0));
    await tester.pumpAndSettle();
    final position = playback.player.position;
    expect(position, greaterThan(const Duration(seconds: 3)));
    await tester.fling(find.byType(Artwork), const Offset(0, 180), 900);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Riduci player'), findsNothing);
    expect(playback.player.position, position);
    await open();
    await tester.tap(find.byTooltip('Riduci player'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Riduci player'), findsNothing);
  });
}
