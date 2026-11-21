import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:void_tracks/playback/playback.dart';
import 'package:void_tracks/widgets/player_controls.dart';

class _Player extends Fake implements AudioPlayer {
  @override
  Duration position = const Duration(seconds: 3);
  @override
  bool hasPrevious = true;
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
      lessThan(tester.getCenter(find.byIcon(Icons.play_arrow)).dx),
    );
    await tester.tap(previous);
    expect(playback.previousCalls, 1);
    expect(opened, isFalse);
    await tester.tap(find.text('Artista'));
    expect(opened, isTrue);
  });
}
