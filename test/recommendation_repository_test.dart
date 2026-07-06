import 'dart:convert';

import 'package:blindbox_app/features/catalog/catalog_bundle.dart';
import 'package:blindbox_app/features/catalog/models/catalog_brand.dart';
import 'package:blindbox_app/features/catalog/models/catalog_ip.dart';
import 'package:blindbox_app/features/catalog/models/catalog_series.dart'
    as catalog;
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/recommendations/data/preference_signal_extractor.dart';
import 'package:blindbox_app/features/recommendations/data/recommendation_http_client.dart';
import 'package:blindbox_app/features/recommendations/data/recommendation_repository.dart';
import 'package:blindbox_app/features/recommendations/domain/recommendation_reason_type.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/collection_fixtures.dart';

const _installId = 'install-test-1';

CollectionSnapshot _ownedCollectionSnapshot() {
  return CollectionSnapshot(
    shelfSeries: [
      testShelfSeries(
        id: 'owned',
        catalogTemplateId: 'dimoo_owned',
        taxonomyIpId: 'dimoo',
        figures: [
          const ShelfFigure(
            id: 'owned_fig',
            seriesId: 'owned',
            name: 'Owned',
            rarity: 'Regular',
            isSecret: false,
            catalogFigureTemplateId: 'fig_owned',
          ),
        ],
      ),
    ],
    figureStates: const {
      'owned_fig': TrackedFigure(
        figureId: 'owned_fig',
        state: FigureCollectionState.owned,
      ),
    },
  );
}

CatalogSeedBundle _testBundle() {
  return CatalogSeedBundle(
    brands: const [
      CatalogBrand(id: 'popmart', displayName: 'POP MART'),
    ],
    ips: const [
      CatalogIp(id: 'dimoo', brandId: 'popmart', displayName: 'DIMOO'),
    ],
    series: const [
      catalog.CatalogSeries(
        id: 'dimoo_owned',
        brandId: 'popmart',
        ipId: 'dimoo',
        displayName: 'Dimoo Owned',
        releaseDate: '2026-01-01',
        isBlindBox: true,
        imageKey: 'dimoo_owned',
      ),
      catalog.CatalogSeries(
        id: 'dimoo_new',
        brandId: 'popmart',
        ipId: 'dimoo',
        displayName: 'Dimoo New',
        releaseDate: '2026-05-01',
        isBlindBox: true,
        imageKey: 'dimoo_new',
      ),
    ],
    figures: const [],
  );
}

PreferenceSignals _ownedSignals() {
  return extractSignals(_ownedCollectionSnapshot());
}

RecommendationHttpClient _httpClient({
  required http.Response forYouResponse,
  void Function(http.Request request)? onProfilePost,
}) {
  return RecommendationHttpClient(
    client: MockClient((request) async {
      if (request.method == 'GET') {
        return forYouResponse;
      }
      if (request.method == 'POST') {
        onProfilePost?.call(request);
        return http.Response(jsonEncode({'ok': true}), 200);
      }
      return http.Response('unexpected', 404);
    }),
  );
}

String _cacheKey() => 'reco_cache_v1_$_installId';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'recommendation_install_id_v1': _installId,
    });
  });

  group('RecommendationRepository.getRecommendations', () {
    test('empty HTTP falls back to local rule engine', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = RecommendationRepository(
        collectionSnapshot: _ownedCollectionSnapshot(),
        httpClient: _httpClient(
          forYouResponse: http.Response(jsonEncode({'items': []}), 200),
        ),
        preferences: prefs,
      );

      final result = await repo.getRecommendations(_installId, _testBundle());

      expect(result.items, isNotEmpty);
      expect(result.items.map((item) => item.seriesId), contains('dimoo_new'));
      expect(
        result.items.firstWhere((item) => item.seriesId == 'dimoo_new').reasonType,
        RecommendationReasonType.recentRelease,
      );
    });

    test('empty HTTP response is not cached', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = RecommendationRepository(
        collectionSnapshot: _ownedCollectionSnapshot(),
        httpClient: _httpClient(
          forYouResponse: http.Response(jsonEncode({'items': []}), 200),
        ),
        preferences: prefs,
      );

      await repo.getRecommendations(_installId, _testBundle());

      final raw = prefs.getString(_cacheKey());
      expect(raw, isNotNull);
      final decoded = jsonDecode(raw!) as Map<String, dynamic>;
      final items = decoded['items'] as List<dynamic>;
      expect(items, isNotEmpty);
    });

    test('stale empty cache is ignored and local fallback still runs', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _cacheKey(),
        jsonEncode({
          'fetchedAt': DateTime.now().toIso8601String(),
          'items': [],
        }),
      );

      final repo = RecommendationRepository(
        collectionSnapshot: _ownedCollectionSnapshot(),
        httpClient: _httpClient(
          forYouResponse: http.Response(jsonEncode({'items': []}), 200),
        ),
        preferences: prefs,
      );

      final result = await repo.getRecommendations(_installId, _testBundle());

      expect(result.items, isNotEmpty);
    });
  });

  group('RecommendationRepository.updateProfile', () {
    test('successful profile upload invalidates recommendation cache', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _cacheKey(),
        jsonEncode({
          'fetchedAt': DateTime.now().toIso8601String(),
          'items': [
            {
              'seriesId': 'dimoo_new',
              'reasonType': RecommendationReasonType.ownedIp,
              'reasonMeta': 'DIMOO',
            },
          ],
        }),
      );

      final repo = RecommendationRepository(
        collectionSnapshot: _ownedCollectionSnapshot(),
        httpClient: _httpClient(
          forYouResponse: http.Response(jsonEncode({'items': []}), 200),
          onProfilePost: (request) {
            expect(request.url.path, endsWith('/v1/profile'));
          },
        ),
        preferences: prefs,
      );

      await repo.updateProfile(_installId, _ownedSignals());

      expect(prefs.getString(_cacheKey()), isNull);
    });
  });
}
