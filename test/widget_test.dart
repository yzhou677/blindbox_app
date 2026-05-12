import 'package:blindbox_app/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App shell shows Home tab', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: BlindboxApp()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsWidgets);
    expect(find.text('Latest drops and new releases will appear here.'), findsOneWidget);
  });
}
