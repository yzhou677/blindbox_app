import 'package:blindbox_app/features/market/utils/open_market_listing_url.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('openMarketListingUrl failure shows Couldn\'t open listing.', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () => openMarketListingUrl(context, 'not-a-url'),
                child: const Text('open'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pump();

    expect(find.text("Couldn't open listing."), findsOneWidget);
  });
}
