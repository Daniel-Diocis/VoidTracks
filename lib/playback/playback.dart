import 'dart:async';

import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../models/song.dart';

class Playback {
  final AudioPlayer player;
  final _errors = StreamController<Object>.broadcast();
  Stream<Object> get errors => _errors.stream;
  List<Song> _queue = [];
  Future<void> _pending = Future.value();
  late final StreamSubscription<PlaybackEvent> _events;

  Playback({AudioPlayer? audioPlayer}) : player = audioPlayer ?? AudioPlayer() {
    _events = player.playbackEventStream.listen((_) {}, onError: _errors.add);
  }

  Future<void> initialize() => player.setLoopMode(LoopMode.all);

  // play() termina alla pausa o a fine brano. I comandi successivi devono
  // poter cambiare la sorgente mentre la riproduzione è in corso.
  void _play() =>
      unawaited(player.play().catchError((Object e) => _errors.add(e)));

  Future<void> _command(Future<void> Function() action) {
    final result = _pending.then((_) => action());
    _pending = result.catchError((Object error) => _errors.add(error));
    return _pending;
  }

  Future<void> select(List<Song> songs, Song song) => _command(() async {
    final index = songs.indexWhere((s) => s.id == song.id);
    if (index < 0) return;
    if (_sameQueue(songs)) {
      if (player.currentIndex == index) {
        await _toggle();
        return;
      }
      await player.seek(Duration.zero, index: index);
    } else {
      await _load(songs, index, Duration.zero);
    }
    _play();
  });

  bool _sameQueue(List<Song> other) {
    if (other.length != _queue.length) return false;
    for (var i = 0; i < other.length; i++) {
      if (other[i].id != _queue[i].id ||
          other[i].audio != _queue[i].audio ||
          other[i].updatedAt != _queue[i].updatedAt) {
        return false;
      }
    }
    return true;
  }

  Future<void> _load(List<Song> songs, int index, Duration position) async {
    final sources =
        songs
            .map(
              (s) => AudioSource.uri(
                s.audio,
                tag: MediaItem(
                  id: s.id,
                  title: s.title,
                  artist: s.artist,
                  album: s.album,
                  artUri: s.cover,
                ),
              ),
            )
            .toList();
    _queue = [];
    await player.setAudioSource(
      ConcatenatingAudioSource(children: sources),
      initialIndex: index,
      initialPosition: position,
    );
    _queue = List.of(songs);
  }

  Future<void> refreshDownloads(List<Song> downloads) => _command(() async {
    if (_queue.isEmpty || _queue.first.audio.scheme != 'file') return;
    final byId = {for (final s in downloads) s.id: s};
    final updated = [
      for (final s in _queue)
        if (byId.containsKey(s.id)) byId[s.id]!,
    ];
    if (_sameQueue(updated)) return;
    if (updated.isEmpty) {
      await player.stop();
      await player.setAudioSource(
        ConcatenatingAudioSource(children: []),
        preload: false,
      );
      _queue = [];
      return;
    }
    final oldIndex = player.currentIndex ?? 0;
    final currentId = _queue[oldIndex].id;
    final index = updated.indexWhere((s) => s.id == currentId);
    final playing = player.playing;
    await _load(
      updated,
      index >= 0 ? index : oldIndex.clamp(0, updated.length - 1),
      index >= 0 ? player.position : Duration.zero,
    );
    if (playing) _play();
  });

  Future<void> _toggle() async {
    if (player.playing) {
      await player.pause();
    } else {
      _play();
    }
  }

  Future<void> toggle() => _command(_toggle);
  Future<void> next() => _command(player.seekToNext);
  Future<void> previous() => _command(() async {
    if (player.position >= const Duration(seconds: 3) || !player.hasPrevious) {
      await player.seek(Duration.zero);
    } else {
      await player.seekToPrevious();
    }
  });
  Future<void> seek(Duration duration) => _command(() => player.seek(duration));

  Future<void> dispose() async {
    await _events.cancel();
    await _pending;
    await player.dispose();
    await _errors.close();
  }
}
