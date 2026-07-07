import 'package:blindbox_app/features/recommendations/data/anonymous_install_id.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

final anonymousInstallIdProvider = FutureProvider<String>((ref) async {
  try {
    return await AnonymousInstallId.getOrCreate();
  } catch (_) {
    return AnonymousInstallId.peek() ?? const Uuid().v4();
  }
});
