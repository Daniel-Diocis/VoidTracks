import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:material_color_utilities/score/score.dart';

const playerFallbackColor = Color(0xff263032);

/// Samples the same cached image used by Artwork, regardless of its source.
Future<Color> coverColor(ImageProvider? provider) async {
  if (provider == null) return playerFallbackColor;
  final stream = provider.resolve(ImageConfiguration.empty);
  final loaded = Completer<ImageInfo>();
  final listener = ImageStreamListener(
    (info, _) {
      if (loaded.isCompleted) {
        info.dispose();
      } else {
        loaded.complete(info);
      }
    },
    onError: (Object error, StackTrace? trace) {
      if (!loaded.isCompleted) loaded.completeError(error, trace);
    },
  );
  ImageInfo? info;
  ui.Picture? picture;
  ui.Image? sample;
  try {
    stream.addListener(listener);
    info = await loaded.future.timeout(const Duration(seconds: 8));
    final image = info.image;
    const size = 32;
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      const Rect.fromLTWH(0, 0, 32, 32),
      Paint()..filterQuality = FilterQuality.low,
    );
    picture = recorder.endRecording();
    sample = await picture.toImage(size, size);
    final bytes = await sample.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (bytes == null) return playerFallbackColor;
    final counts = <int, int>{};
    for (var i = 0; i < bytes.lengthInBytes; i += 4) {
      if (bytes.getUint8(i + 3) < 200) continue;
      final rgb =
          0xff000000 |
          (bytes.getUint8(i) << 16) |
          (bytes.getUint8(i + 1) << 8) |
          bytes.getUint8(i + 2);
      counts[rgb] = (counts[rgb] ?? 0) + 1;
    }
    final seed =
        Score.score(counts, desired: 1, fallbackColorARGB: 0xff505050).first;
    final tone = HSLColor.fromColor(Color(seed));
    return tone
        .withLightness(0.23)
        .withSaturation(tone.saturation.clamp(0.0, 0.62))
        .toColor();
  } catch (_) {
    return playerFallbackColor;
  } finally {
    stream.removeListener(listener);
    sample?.dispose();
    picture?.dispose();
    info?.dispose();
  }
}
