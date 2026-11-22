import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

class Artwork extends StatelessWidget {
  const Artwork(this.uri, {super.key, this.size = 48});
  final Uri? uri;
  final double size;

  static ImageProvider? providerFor(Uri? source) {
    if (source == null) return null;
    return source.scheme == 'file'
        ? FileImage(File.fromUri(source))
        : NetworkImage(source.toString());
  }

  @override
  Widget build(BuildContext context) {
    Widget placeholder() => const ColoredBox(
      color: Color(0xff30343b),
      child: Center(child: Icon(Icons.music_note, color: Colors.white70)),
    );
    final image = providerFor(uri);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox.square(
        dimension: size,
        child:
            image == null
                ? placeholder()
                : Image(
                  image: image,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) => placeholder(),
                ),
      ),
    );
  }
}

Future<ImageInfo> loadArtwork(ImageProvider provider) async {
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
  try {
    stream.addListener(listener);
    return await loaded.future.timeout(const Duration(seconds: 8));
  } finally {
    stream.removeListener(listener);
  }
}
