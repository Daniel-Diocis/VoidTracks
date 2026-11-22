import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:void_tracks/widgets/swipe_remove.dart';

void main() {
  testWidgets('Solo uno swipe completo verso sinistra richiede la rimozione', (
    tester,
  ) async {
    var removals = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: SwipeRemove(
                key: const ValueKey('track'),
                label: 'Rimuovi dalla playlist',
                onRemove: () async {
                  removals++;
                },
                child: const ListTile(title: Text('Brano')),
              ),
            ),
          ),
        ),
      ),
    );
    final row = find.byType(SwipeRemove);
    await tester.drag(row, const Offset(140, 0));
    await tester.pumpAndSettle();
    await tester.drag(row, const Offset(-40, 0));
    await tester.pumpAndSettle();
    expect(removals, 0);
    await tester.drag(row, const Offset(-220, 0));
    await tester.pumpAndSettle();
    expect(removals, 1);
    // A cancelled download confirmation leaves the row usable for another swipe.
    await tester.drag(row, const Offset(-220, 0));
    await tester.pumpAndSettle();
    expect(removals, 2);
  });
}
