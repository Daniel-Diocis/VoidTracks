import 'dart:typed_data';

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:void_tracks/screens/settings_screen.dart';
import 'package:void_tracks/settings/theme_preference.dart';
import 'package:void_tracks/widgets/cover_color.dart';

Future<Color> _sampleCover(void Function(Canvas) draw) async {
  final recorder = ui.PictureRecorder();
  draw(Canvas(recorder));
  final picture = recorder.endRecording();
  final image = await picture.toImage(32, 32);
  try {
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    return await coverColor(MemoryImage(png!.buffer.asUint8List()));
  } finally {
    image.dispose();
    picture.dispose();
  }
}

void main() {
  testWidgets('Il tema cambia subito e viene riletto al prossimo avvio', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final preference = ThemePreference(prefs);
    expect(preference.value, ThemeMode.system);
    await tester.pumpWidget(
      ValueListenableBuilder<ThemeMode>(
        valueListenable: preference,
        builder:
            (_, mode, __) => MaterialApp(
              theme: appTheme(Brightness.light),
              darkTheme: appTheme(Brightness.dark),
              themeMode: mode,
              home: SettingsScreen(preference),
            ),
      ),
    );
    await tester.tap(find.text('Scuro'));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.text('Tema'))).brightness,
      Brightness.dark,
    );
    await prefs.reload();
    expect(ThemePreference(prefs).value, ThemeMode.dark);
    await tester.tap(find.text('Chiaro'));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.text('Tema'))).brightness,
      Brightness.light,
    );
  });

  testWidgets(
    'Lo sfondo conserva la tinta della cover e il contrasto con il bianco',
    (tester) async {
      await tester.runAsync(() async {
        for (final color in [Colors.red, Colors.blue]) {
          final result = await _sampleCover(
            (canvas) => canvas.drawColor(color, BlendMode.src),
          );
          expect(
            HSLColor.fromColor(result).hue,
            closeTo(HSLColor.fromColor(color).hue, 2),
          );
          expect(1.05 / (result.computeLuminance() + 0.05), greaterThan(4.5));
          expect(HSLColor.fromColor(result).saturation, lessThan(.45));
        }
        final neutral = await _sampleCover((canvas) {
          canvas.drawColor(Colors.grey, BlendMode.src);
          canvas.drawRect(
            const Rect.fromLTWH(0, 0, 5, 5),
            Paint()..color = Colors.red,
          );
        });
        expect(HSLColor.fromColor(neutral).saturation, 0);
        final mixed = await _sampleCover((canvas) {
          canvas.drawColor(Colors.white, BlendMode.src);
          canvas.drawRect(
            const Rect.fromLTWH(0, 0, 12, 32),
            Paint()..color = const Color(0xffff0000),
          );
          canvas.drawRect(
            const Rect.fromLTWH(12, 0, 10, 32),
            Paint()..color = const Color(0xff829fc2),
          );
        });
        expect(HSLColor.fromColor(mixed).hue, closeTo(213, 4));
        expect(await coverColor(null), playerFallbackColor);
        expect(
          await coverColor(MemoryImage(Uint8List.fromList([1, 2, 3]))),
          playerFallbackColor,
        );
      });
    },
  );
}
