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
import 'package:blindbox_app/features/recommendations/domain/recommendation_item.dart';
import 'package:blindbox_app/features/recommendations/domain/recommendation_reason_type.dart';
import 'package:blindbox_app/features/recommendations/domain/recommendation_result.dart';
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

CollectionSnapshot _expandedCollectionSnapshot() {
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
      testShelfSeries(
        id: 'also_owned',
        catalogTemplateId: 'dimoo_new',
        taxonomyIpId: 'dimoo',
        figures: [
          const ShelfFigure(
            id: 'also_owned_fig',
            seriesId: 'also_owned',
            name: 'Also Owned',
            rarity: 'Regular',
            isSecret: false,
            catalogFigureTemplateId: 'fig_also_owned',
          ),
        ],
      ),
    ],
    figureStates: const {
      'owned_fig': TrackedFigure(
        figureId: 'owned_fig',
        state: FigureCollectionState.owned,
      ),
      'also_owned_fig': TrackedFigure(
        figureId: 'also_owned_fig',
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
  void Function(http.Request request)? onForYouGet,
}) {
  return RecommendationHttpClient(
    client: MockClient((request) async {
      if (request.method == 'GET') {
        onForYouGet?.call(request);
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

String _cacheKey() => 'reco_cache_v2_$_installId';

Map<String, dynamic> _cacheJson({
  required String profileHash,
  required List<Map<String, dynamic>> items,
  int schemaVersion = 1,
}) {
  return {
    'schemaVersion': schemaVersion,
    'profileHash': profileHash,
    'items': items,
  };
}

void main() {
  setUp(() {
    RecommendationRepository.resetComputedMemoForTest();
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
      expect(result.profileHash, _ownedSignals().profileHash);
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
      expect(decoded['profileHash'], _ownedSignals().profileHash);
      expect(decoded['schemaVersion'], 1);
      final items = decoded['items'] as List<dynamic>;
      expect(items, isNotEmpty);
    });

    test('returns session memo when profileHash unchanged without HTTP', () async {
      final prefs = await SharedPreferences.getInstance();
      var httpCalls = 0;
      final repo = RecommendationRepository(
        collectionSnapshot: _ownedCollectionSnapshot(),
        httpClient: _httpClient(
          forYouResponse: http.Response(
            jsonEncode({
              'items': [
                {
                  'seriesId': 'dimoo_new',
                  'reasonType': RecommendationReasonType.ownedIp,
                  'reasonMeta': 'DIMOO',
                },
              ],
            }),
            200,
          ),
          onForYouGet: (_) => httpCalls++,
        ),
        preferences: prefs,
      );

      await repo.getRecommendations(_installId, _testBundle());
      expect(httpCalls, 1);

      final secondPass = RecommendationRepository(
        collectionSnapshot: _ownedCollectionSnapshot(),
        httpClient: _httpClient(
          forYouResponse: http.Response('should not be called', 500),
          onForYouGet: (_) => httpCalls++,
        ),
        preferences: prefs,
      );

      final result = await secondPass.getRecommendations(_installId, _testBundle());

      expect(httpCalls, 1);
      expect(result.items.single.seriesId, 'dimoo_new');
    });

    test('returns cache when profileHash matches without HTTP', () async {
      final prefs = await SharedPreferences.getInstance();
      final signals = _ownedSignals();
      await prefs.setString(
        _cacheKey(),
        jsonEncode(
          _cacheJson(
            profileHash: signals.profileHash,
            items: [
              {
                'seriesId': 'dimoo_new',
                'reasonType': RecommendationReasonType.ownedIp,
                'reasonMeta': 'DIMOO',
              },
            ],
          ),
        ),
      );

      var httpCalled = false;
      final repo = RecommendationRepository(
        collectionSnapshot: _ownedCollectionSnapshot(),
        httpClient: _httpClient(
          forYouResponse: http.Response('should not be called', 500),
          onForYouGet: (_) => httpCalled = true,
        ),
        preferences: prefs,
      );

      final result = await repo.getRecommendations(_installId, _testBundle());

      expect(httpCalled, isFalse);
      expect(result.items.single.seriesId, 'dimoo_new');
    });

    test('schema version mismatch bypasses cache and hits HTTP', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _cacheKey(),
        jsonEncode(
          _cacheJson(
            profileHash: _ownedSignals().profileHash,
            schemaVersion: 0,
            items: [
              {
                'seriesId': 'dimoo_new',
                'reasonType': RecommendationReasonType.ownedIp,
                'reasonMeta': 'DIMOO',
              },
            ],
          ),
        ),
      );

      var httpCalled = false;
      final repo = RecommendationRepository(
        collectionSnapshot: _ownedCollectionSnapshot(),
        httpClient: _httpClient(
          forYouResponse: http.Response(
            jsonEncode({
              'items': [
                {
                  'seriesId': 'dimoo_new',
                  'reasonType': RecommendationReasonType.ownedIp,
                  'reasonMeta': 'DIMOO',
                },
              ],
            }),
            200,
          ),
          onForYouGet: (_) => httpCalled = true,
        ),
        preferences: prefs,
      );

      await repo.getRecommendations(_installId, _testBundle());

      expect(httpCalled, isTrue);
    });

    test('profileHash mismatch bypasses cache and hits HTTP', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _cacheKey(),
        jsonEncode(
          _cacheJson(
            profileHash: 'stale-profile-hash',
            items: [
              {
                'seriesId': 'dimoo_new',
                'reasonType': RecommendationReasonType.ownedIp,
                'reasonMeta': 'DIMOO',
              },
            ],
          ),
        ),
      );

      var httpCalled = false;
      final repo = RecommendationRepository(
        collectionSnapshot: _ownedCollectionSnapshot(),
        httpClient: _httpClient(
          forYouResponse: http.Response(
            jsonEncode({
              'items': [
                {
                  'seriesId': 'dimoo_new',
                  'reasonType': RecommendationReasonType.ownedIp,
                  'reasonMeta': 'DIMOO',
                },
              ],
            }),
            200,
          ),
          onForYouGet: (_) => httpCalled = true,
        ),
        preferences: prefs,
      );

      await repo.getRecommendations(_installId, _testBundle());

      expect(httpCalled, isTrue);
    });

    test('excludeOwnedCatalogSeries removes owned catalog picks', () {
      final signals = extractSignals(_ownedCollectionSnapshot());
      final filtered = excludeOwnedCatalogSeries(
        RecommendationResult(
          items: const [
            RecommendationItem(
              seriesId: 'dimoo_new',
              reasonType: RecommendationReasonType.ownedIp,
            ),
            RecommendationItem(
              seriesId: 'dimoo_owned',
              reasonType: RecommendationReasonType.ownedIp,
            ),
          ],
        ),
        signals,
      );

      expect(filtered.items.map((item) => item.seriesId), ['dimoo_new']);
    });

    test('stale cloud response recommending owned series falls back to local', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = RecommendationRepository(
        collectionSnapshot: _expandedCollectionSnapshot(),
        httpClient: _httpClient(
          forYouResponse: http.Response(
            jsonEncode({
              'items': [
                {
                  'seriesId': 'dimoo_new',
                  'reasonType': RecommendationReasonType.ownedIp,
                  'reasonMeta': 'DIMOO',
                },
              ],
            }),
            200,
          ),
        ),
        preferences: prefs,
      );

      final result = await repo.getRecommendations(_installId, _testBundle());

      expect(result.items.map((item) => item.seriesId), isNot(contains('dimoo_new')));
      expect(result.items, isEmpty);
    });

    test('oversized stale cache is ignored and local fallback still runs', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _cacheKey(),
        jsonEncode({
          'schemaVersion': 1,
          'profileHash': _ownedSignals().profileHash,
          'items': [
            for (var i = 0; i < 20; i++)
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
        ),
        preferences: prefs,
      );

      final result = await repo.getRecommendations(_installId, _testBundle());

      expect(result.items.length, lessThanOrEqualTo(10));
    });

    test('stale empty cache is ignored and local fallback still runs', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _cacheKey(),
        jsonEncode({
          'schemaVersion': 1,
          'profileHash': _ownedSignals().profileHash,
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
        jsonEncode(
          _cacheJson(
            profileHash: _ownedSignals().profileHash,
            items: [
              {
                'seriesId': 'dimoo_new',
                'reasonType': RecommendationReasonType.ownedIp,
                'reasonMeta': 'DIMOO',
              },
            ],
          ),
        ),
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
