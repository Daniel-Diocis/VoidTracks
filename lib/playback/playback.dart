import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import '../models/song.dart';

class Playback extends BaseAudioHandler with SeekHandler {
  final AudioPlayer player;
  final _errors = StreamController<Object>.broadcast();
  Stream<Object> get errors => _errors.stream;
  List<Song> _queue = [];
  Song? queuedSong(String id) => _queue.where((s) => s.id == id).firstOrNull;
  Future<void> _pending = Future.value();
  final _subscriptions = <StreamSubscription<dynamic>>[];

  Playback({AudioPlayer? audioPlayer}) : player = audioPlayer ?? AudioPlayer();

  Future<void> initialize() async {
    await player.setLoopMode(LoopMode.all);
    _subscriptions.add(
      player.sequenceStream.listen((sources) {
        queue.add([
          for (final source in sources ?? <IndexedAudioSource>[])
            source.tag as MediaItem,
        ]);
        _publishEvent(player.playbackEvent);
      }),
    );
    _subscriptions.add(
      player.playbackEventStream.listen(
        _publishEvent,
        onError: (Object error) {
          _errors.add(error);
          playbackState.add(
            playbackState.value.copyWith(
              processingState: AudioProcessingState.error,
              errorCode: error is PlayerException ? error.code : 1,
              errorMessage: error.toString(),
            ),
          );
        },
      ),
    );
  }

  void _publishEvent(PlaybackEvent event) {
    final items = queue.value;
    final index = event.currentIndex;
    MediaItem? item;
    if (index != null && index >= 0 && index < items.length) {
      item = items[index];
      if (event.duration != null && item.duration != event.duration) {
        item = item.copyWith(duration: event.duration);
        queue.add(List.of(items)..[index] = item);
      }
    }
    if (!identical(mediaItem.value, item)) mediaItem.add(item);
    final state = event.processingState;
    final playing =
        player.playing &&
        state != ProcessingState.completed &&
        state != ProcessingState.idle;
    final controls = [
      if (item != null) MediaControl.skipToPrevious,
      if (playing) MediaControl.pause else MediaControl.play,
      if (player.hasNext) MediaControl.skipToNext,
    ];
    playbackState.add(
      PlaybackState(
        controls: controls,
        androidCompactActionIndices: List.generate(
          controls.length,
          (index) => index,
        ),
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        processingState: switch (state) {
          ProcessingState.idle => AudioProcessingState.idle,
          ProcessingState.loading => AudioProcessingState.loading,
          ProcessingState.buffering => AudioProcessingState.buffering,
          ProcessingState.ready => AudioProcessingState.ready,
          ProcessingState.completed => AudioProcessingState.completed,
        },
        playing: playing,
        updatePosition: player.position,
        bufferedPosition: event.bufferedPosition,
        queueIndex: item == null ? null : index,
        speed: player.speed,
        repeatMode: switch (player.loopMode) {
          LoopMode.off => AudioServiceRepeatMode.none,
          LoopMode.one => AudioServiceRepeatMode.one,
          LoopMode.all => AudioServiceRepeatMode.all,
        },
        shuffleMode:
            player.shuffleModeEnabled
                ? AudioServiceShuffleMode.all
                : AudioServiceShuffleMode.none,
      ),
    );
  }

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
    if (!_queue.any((s) => s.audio.scheme == 'file')) return;
    final byId = {for (final s in downloads) s.id: s};
    final updated = [
      for (final s in _queue)
        if (s.audio.scheme != 'file')
          s
        else if (byId.containsKey(s.id))
          byId[s.id]!,
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
  @override
  Future<void> play() => _command(() async {
    if (player.processingState == ProcessingState.completed) {
      await player.seek(Duration.zero, index: 0);
    }
    _play();
  });

  @override
  Future<void> pause() => _command(player.pause);

  @override
  Future<void> stop() => _command(player.stop);

  @override
  Future<void> skipToQueueItem(int index) => _command(() async {
    if (index >= 0 && index < _queue.length) {
      await player.seek(Duration.zero, index: index);
    }
  });

  @override
  Future<void> setSpeed(double speed) => _command(() => player.setSpeed(speed));

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) =>
      _command(() async {
        await player.setLoopMode(switch (repeatMode) {
          AudioServiceRepeatMode.none => LoopMode.off,
          AudioServiceRepeatMode.one => LoopMode.one,
          _ => LoopMode.all,
        });
        _publishEvent(player.playbackEvent);
      });

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) =>
      _command(() async {
        await player.setShuffleModeEnabled(
          shuffleMode != AudioServiceShuffleMode.none,
        );
        _publishEvent(player.playbackEvent);
      });

  @override
  Future<void> skipToNext() => _command(player.seekToNext);
  @override
  Future<void> skipToPrevious() => _command(() async {
    if (player.position >= const Duration(seconds: 3) || !player.hasPrevious) {
      await player.seek(Duration.zero);
    } else {
      await player.seekToPrevious();
    }
  });
  @override
  Future<void> seek(Duration position) => _command(() => player.seek(position));

  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _pending;
    await player.dispose();
    await _errors.close();
  }
}
