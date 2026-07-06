import 'package:blindbox_app/features/catalog/application/catalog_bundle_provider.dart';
import 'package:blindbox_app/features/recommendations/application/anonymous_id_provider.dart';
import 'package:blindbox_app/features/recommendations/data/recommendation_repository.dart';
import 'package:blindbox_app/features/recommendations/domain/recommendation_result.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final recommendationsProvider =
    FutureProvider<RecommendationResult>((ref) async {
  final id = await ref.watch(anonymousInstallIdProvider.future);
  final bundle = await ref.watch(catalogBundleProvider.future);
  final repo = ref.watch(recommendationRepositoryProvider);
  return repo.getRecommendations(id, bundle);
});
