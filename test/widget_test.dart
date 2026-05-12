import 'package:blindbox_app/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App shell shows Home tab', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: BlindboxApp()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Home'), findsWidgets);
    expect(find.text('Discover'), findsWidgets);
    expect(find.text('Latest drops'), findsOneWidget);
    expect(find.text('Luna Astronaut'), findsOneWidget);
  });
}
