import 'package:blindbox_app/features/recommendations/data/anonymous_install_id.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final anonymousInstallIdProvider = FutureProvider<String>((ref) {
  return AnonymousInstallId.getOrCreate();
});
