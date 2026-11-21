import 'dart:io';

import 'package:flutter/material.dart';

class Artwork extends StatelessWidget {
  const Artwork(this.uri, {super.key, this.size = 48});
  final Uri? uri;
  final double size;

  @override
  Widget build(BuildContext context) {
    final source = uri;
    Widget placeholder() => const ColoredBox(
      color: Color(0xff30343b),
      child: Center(child: Icon(Icons.music_note, color: Colors.white70)),
    );
    final ImageProvider? image =
        source == null
            ? null
            : source.scheme == 'file'
            ? FileImage(File.fromUri(source))
            : NetworkImage(source.toString());
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
