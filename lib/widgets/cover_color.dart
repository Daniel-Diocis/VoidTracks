import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

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
      Paint()..filterQuality = FilterQuality.medium,
    );
    picture = recorder.endRecording();
    sample = await picture.toImage(size, size);
    final bytes = await sample.toByteData(format: ui.ImageByteFormat.rawRgba);
    return bytes == null ? playerFallbackColor : _mutedTone(bytes);
  } catch (_) {
    return playerFallbackColor;
  } finally {
    stream.removeListener(listener);
    sample?.dispose();
    picture?.dispose();
    info?.dispose();
  }
}

Color _mutedTone(ByteData pixels) {
  // Group similar shades so a flat, vivid logo doesn't outweigh a shaded area.
  final weights = List.filled(12, 0.0);
  final hueOffsets = List.filled(12, 0.0);
  var opaque = 0;
  var chromatic = 0;
  for (var i = 0; i < pixels.lengthInBytes; i += 4) {
    if (pixels.getUint8(i + 3) < 200) continue;
    opaque++;
    final color = Color.fromARGB(
      255,
      pixels.getUint8(i),
      pixels.getUint8(i + 1),
      pixels.getUint8(i + 2),
    );
    final tone = HSLColor.fromColor(color);
    final chroma = tone.saturation * (1 - (2 * tone.lightness - 1).abs());
    if (chroma < .09) continue;
    chromatic++;
    final sector = (tone.hue / 30).round();
    final bin = sector % 12;
    final weight = 1 - .8 * tone.saturation * tone.saturation;
    weights[bin] += weight;
    hueOffsets[bin] += weight * (tone.hue - sector * 30);
  }
  if (opaque == 0) return playerFallbackColor;
  final coverage = chromatic / opaque;
  if (coverage < .06) return const Color(0xff393939);
  var best = 0;
  for (var bin = 1; bin < weights.length; bin++) {
    if (weights[bin] > weights[best]) best = bin;
  }
  final hue = (best * 30 + hueOffsets[best] / weights[best]) % 360;
  final saturation = .16 + .26 * coverage;
  return HSLColor.fromAHSL(1, hue, saturation, .18).toColor();
}
