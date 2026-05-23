import 'dart:async';

import 'package:blindbox_app/features/market/data/market_listings_bootstrap.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  await bootstrapMarketBrowseListings();
  await testMain();
}
