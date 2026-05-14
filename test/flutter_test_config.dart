import 'dart:async';

import 'package:blindbox_app/features/market/data/market_listings_bootstrap.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await bootstrapMarketBrowseListings();
  await testMain();
}
