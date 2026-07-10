import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:example/demos/aligned_rect_fit/aligned_rect_fit_demo.dart';
import 'package:example/main.dart';

void main() {
  testWidgets('loads demo menu', (WidgetTester tester) async {
    await tester.pumpWidget(const InfinityCanvasExampleApp());

    expect(find.text('Infinity Canvas Examples'), findsWidgets);
    expect(find.text('Aligned Rectangle Fit'), findsOneWidget);
    expect(find.text('Minimal Items'), findsOneWidget);
  });

  testWidgets('aligned fit demo renders and applies varied options', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const MaterialApp(home: AlignedRectFitDemoPage()));
    await tester.pumpAndSettle();

    expect(find.text('Aligned Rectangle Fit'), findsOneWidget);
    expect(find.text('Apply fit'), findsOneWidget);
    expect(find.textContaining('760 × 480 world rect'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('width'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('height').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('topLeft'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('bottomRight').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('16 all'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('asymmetric').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Apply fit'));
    await tester.tap(find.byIcon(Icons.add));
    await tester.tap(find.byIcon(Icons.remove));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(900, 650);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
