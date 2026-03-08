import 'package:flutter_test/flutter_test.dart';

import 'package:example/main.dart';

void main() {
  testWidgets('loads demo menu', (WidgetTester tester) async {
    await tester.pumpWidget(const InfinityCanvasExampleApp());

    expect(find.text('Infinity Canvas Examples'), findsWidgets);
    expect(find.text('Minimal Items'), findsOneWidget);
  });
}
