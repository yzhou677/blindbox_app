import 'dart:convert';

import 'package:blindbox_app/features/catalog/catalog_bundle.dart';
import 'package:blindbox_app/features/catalog/models/catalog_brand.dart';
import 'package:blindbox_app/features/catalog/models/catalog_ip.dart';
import 'package:blindbox_app/features/catalog/models/catalog_series.dart'
    as catalog;
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/bootstrap/collection_app_bootstrap.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/recommendations/data/preference_signal_extractor.dart';
import 'package:blindbox_app/features/recommendations/data/recommendation_http_client.dart';
import 'package:blindbox_app/features/recommendations/data/recommendation_repository.dart';
import 'package:blindbox_app/features/recommendations/domain/recommendation_item.dart';
import 'package:blindbox_app/features/recommendations/domain/recommendation_reason_type.dart';
import 'package:blindbox_app/features/recommendations/domain/recommendation_result.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

CollectionSnapshot _nommiHeavyCollectionSnapshot() {
  return CollectionSnapshot(
    shelfSeries: [
      for (var i = 1; i <= 3; i++)
        testShelfSeries(
          id: 'shelf_nommi_$i',
          name: 'Nommi Owned $i',
          catalogTemplateId: 'nommi_owned_$i',
          taxonomyIpId: 'nommi',
          ipName: 'NOMMI',
        ),
    ],
    figureStates: const {},
  );
}

CatalogSeedBundle _nommiBundle() {
  return CatalogSeedBundle(
    brands: const [
      CatalogBrand(id: 'popmart', displayName: 'POP MART'),
    ],
    ips: const [
      CatalogIp(id: 'nommi', brandId: 'popmart', displayName: 'NOMMI'),
      CatalogIp(id: 'labubu', brandId: 'popmart', displayName: 'LABUBU'),
    ],
    series: const [
      catalog.CatalogSeries(
        id: 'nommi_owned_1',
        brandId: 'popmart',
        ipId: 'nommi',
        displayName: 'Nommi Owned 1',
        releaseDate: '2026-01-01',
        isBlindBox: true,
        imageKey: 'nommi_owned_1',
      ),
      catalog.CatalogSeries(
        id: 'nommi_owned_2',
        brandId: 'popmart',
        ipId: 'nommi',
        displayName: 'Nommi Owned 2',
        releaseDate: '2026-01-02',
        isBlindBox: true,
        imageKey: 'nommi_owned_2',
      ),
      catalog.CatalogSeries(
        id: 'nommi_owned_3',
        brandId: 'popmart',
        ipId: 'nommi',
        displayName: 'Nommi Owned 3',
        releaseDate: '2026-01-03',
        isBlindBox: true,
        imageKey: 'nommi_owned_3',
      ),
      catalog.CatalogSeries(
        id: 'nommi_reco',
        brandId: 'popmart',
        ipId: 'nommi',
        displayName: 'Nommi Reco',
        releaseDate: '2026-05-01',
        isBlindBox: true,
        imageKey: 'nommi_reco',
      ),
      catalog.CatalogSeries(
        id: 'labubu_other',
        brandId: 'popmart',
        ipId: 'labubu',
        displayName: 'Labubu Other',
        releaseDate: '2026-05-02',
        isBlindBox: true,
        imageKey: 'labubu_other',
      ),
    ],
    figures: const [],
  );
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
        result.items.firstWhere((item) => item.seriesId == 'dimoo_new').primaryReasonType,
        RecommendationReasonType.trackedIp,
      );
      expect(
        result.items.firstWhere((item) => item.seriesId == 'dimoo_new').secondaryReasonType,
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
                  'reasonType': RecommendationReasonType.trackedIp,
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
                'reasonType': RecommendationReasonType.trackedIp,
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
                'reasonType': RecommendationReasonType.trackedIp,
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
                  'reasonType': RecommendationReasonType.trackedIp,
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
                'reasonType': RecommendationReasonType.trackedIp,
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
                  'reasonType': RecommendationReasonType.trackedIp,
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

    test('excludeTrackedCatalogSeries removes tracked catalog picks', () {
      final signals = extractSignals(_ownedCollectionSnapshot());
      final filtered = excludeTrackedCatalogSeries(
        RecommendationResult(
          items: const [
            RecommendationItem(
              seriesId: 'dimoo_new',
              primaryReasonType: RecommendationReasonType.trackedIp,
            ),
            RecommendationItem(
              seriesId: 'dimoo_owned',
              primaryReasonType: RecommendationReasonType.trackedIp,
            ),
          ],
        ),
        signals,
      );

      expect(filtered.items.map((item) => item.seriesId), ['dimoo_new']);
    });

    test('stale cloud response recommending tracked series falls back to local', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = RecommendationRepository(
        collectionSnapshot: _expandedCollectionSnapshot(),
        httpClient: _httpClient(
          forYouResponse: http.Response(
            jsonEncode({
              'items': [
                {
                  'seriesId': 'dimoo_new',
                  'reasonType': RecommendationReasonType.trackedIp,
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

    test(
      'cloud response with matching profileHash but tracked series rejects whole payload',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final signals = extractSignals(_expandedCollectionSnapshot());
        final repo = RecommendationRepository(
          collectionSnapshot: _expandedCollectionSnapshot(),
          httpClient: _httpClient(
            forYouResponse: http.Response(
              jsonEncode({
                'profileHash': signals.profileHash,
                'items': [
                  {
                    'seriesId': 'dimoo_new',
                    'reasonType': RecommendationReasonType.trackedIp,
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
      },
    );

    test(
      'cloud response with matching profileHash and mixed tracked picks rejects whole payload',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final signals = _ownedSignals();
        final repo = RecommendationRepository(
          collectionSnapshot: _ownedCollectionSnapshot(),
          httpClient: _httpClient(
            forYouResponse: http.Response(
              jsonEncode({
                'profileHash': signals.profileHash,
                'items': [
                  {
                    'seriesId': 'dimoo_new',
                    'reasonType': RecommendationReasonType.trackedIp,
                    'reasonMeta': 'CLOUD_ONLY',
                  },
                  {
                    'seriesId': 'dimoo_owned',
                    'reasonType': RecommendationReasonType.trackedIp,
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

        expect(
          result.items
              .where((item) => item.primaryReasonMeta == 'CLOUD_ONLY')
              .map((item) => item.seriesId),
          isEmpty,
        );
      },
    );

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
                'reasonType': RecommendationReasonType.trackedIp,
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

    test('shelf-only tracked series never returned by repository', () async {
      final snap = CollectionSnapshot(
        shelfSeries: [
          testShelfSeries(
            id: 'shelf_only',
            catalogTemplateId: 'dimoo_owned',
            taxonomyIpId: 'dimoo',
          ),
        ],
        figureStates: const {},
      );
      final prefs = await SharedPreferences.getInstance();
      final repo = RecommendationRepository(
        collectionSnapshot: snap,
        httpClient: _httpClient(
          forYouResponse: http.Response(jsonEncode({'items': []}), 200),
        ),
        preferences: prefs,
      );

      final result = await repo.getRecommendations(_installId, _testBundle());

      expect(
        result.items.map((item) => item.seriesId),
        isNot(contains('dimoo_owned')),
      );
      expect(result.items.map((item) => item.seriesId), contains('dimoo_new'));
    });

    test('add catalog series to shelf excludes it from next repository fetch', () async {
      CollectionAppBootstrap.prime(CollectionSnapshot.emptyTest());
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final prefs = await SharedPreferences.getInstance();
      final repoBefore = RecommendationRepository(
        collectionSnapshot: container.read(collectionNotifierProvider),
        httpClient: _httpClient(
          forYouResponse: http.Response(jsonEncode({'items': []}), 200),
        ),
        preferences: prefs,
      );
      final before = await repoBefore.getRecommendations(_installId, _testBundle());
      expect(before.items.map((item) => item.seriesId), contains('dimoo_owned'));

      container.read(collectionNotifierProvider.notifier).addSeriesFromTemplate(
            testCatalogTemplate(templateId: 'dimoo_owned'),
          );
      final snapAfter = container.read(collectionNotifierProvider);
      expect(extractSignals(snapAfter).trackedCatalogSeriesIds, {'dimoo_owned'});
      expect(extractSignals(snapAfter).ownedCatalogSeriesIds, isEmpty);

      RecommendationRepository.resetComputedMemoForTest();
      final repoAfter = RecommendationRepository(
        collectionSnapshot: snapAfter,
        httpClient: _httpClient(
          forYouResponse: http.Response('should not hit', 500),
        ),
        preferences: prefs,
      );
      final after = await repoAfter.getRecommendations(_installId, _testBundle());

      expect(after.items.map((item) => item.seriesId), isNot(contains('dimoo_owned')));
    });

    test('cloud response without profileHash uses local collection taste', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = RecommendationRepository(
        collectionSnapshot: _nommiHeavyCollectionSnapshot(),
        httpClient: _httpClient(
          forYouResponse: http.Response(
            jsonEncode({
              'items': [
                {
                  'seriesId': 'labubu_other',
                  'reasonType': RecommendationReasonType.newInCatalog,
                },
              ],
            }),
            200,
          ),
        ),
        preferences: prefs,
      );

      final result = await repo.getRecommendations(_installId, _nommiBundle());

      expect(
        result.items.map((item) => item.seriesId),
        contains('nommi_reco'),
      );
      expect(
        result.items
            .where((item) => item.seriesId == 'nommi_reco')
            .first
            .primaryReasonType,
        RecommendationReasonType.trackedIp,
      );
    });

    test('cloud response with stale profileHash uses local collection taste', () async {
      final prefs = await SharedPreferences.getInstance();
      final signals = extractSignals(_nommiHeavyCollectionSnapshot());
      final repo = RecommendationRepository(
        collectionSnapshot: _nommiHeavyCollectionSnapshot(),
        httpClient: _httpClient(
          forYouResponse: http.Response(
            jsonEncode({
              'profileHash': 'stale-profile-hash',
              'items': [
                {
                  'seriesId': 'labubu_other',
                  'reasonType': RecommendationReasonType.newInCatalog,
                },
              ],
            }),
            200,
          ),
        ),
        preferences: prefs,
      );

      final result = await repo.getRecommendations(_installId, _nommiBundle());

      expect(result.profileHash, signals.profileHash);
      expect(
        result.items.map((item) => item.seriesId),
        contains('nommi_reco'),
      );
    });

    test('cloud response with matching profileHash is accepted', () async {
      final prefs = await SharedPreferences.getInstance();
      final signals = _ownedSignals();
      final repo = RecommendationRepository(
        collectionSnapshot: _ownedCollectionSnapshot(),
        httpClient: _httpClient(
          forYouResponse: http.Response(
            jsonEncode({
              'profileHash': signals.profileHash,
              'items': [
                {
                  'seriesId': 'dimoo_new',
                  'reasonType': RecommendationReasonType.trackedIp,
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

      expect(result.items.single.seriesId, 'dimoo_new');
      expect(result.profileHash, signals.profileHash);
    });

    test('add series via template updates recommendations from local shelf', () async {
      CollectionAppBootstrap.prime(CollectionSnapshot.emptyTest());
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final prefs = await SharedPreferences.getInstance();
      final repoBefore = RecommendationRepository(
        collectionSnapshot: container.read(collectionNotifierProvider),
        httpClient: _httpClient(
          forYouResponse: http.Response(jsonEncode({'items': []}), 200),
        ),
        preferences: prefs,
      );
      final before = await repoBefore.getRecommendations(_installId, _nommiBundle());
      expect(
        before.items.map((item) => item.seriesId),
        isNot(contains('nommi_reco')),
      );

      container.read(collectionNotifierProvider.notifier).addSeriesFromTemplate(
            testCatalogTemplate(
              templateId: 'nommi_owned_1',
              taxonomyIpId: 'nommi',
              name: 'Nommi Owned 1',
            ),
          );
      container.read(collectionNotifierProvider.notifier).addSeriesFromTemplate(
            testCatalogTemplate(
              templateId: 'nommi_owned_2',
              taxonomyIpId: 'nommi',
              name: 'Nommi Owned 2',
            ),
          );
      container.read(collectionNotifierProvider.notifier).addSeriesFromTemplate(
            testCatalogTemplate(
              templateId: 'nommi_owned_3',
              taxonomyIpId: 'nommi',
              name: 'Nommi Owned 3',
            ),
          );

      final snapAfter = container.read(collectionNotifierProvider);
      final signals = extractSignals(snapAfter);
      expect(signals.trackedIpIds, {'nommi'});
      expect(signals.trackedCatalogSeriesIds.length, 3);

      RecommendationRepository.resetComputedMemoForTest();
      final repoAfter = RecommendationRepository(
        collectionSnapshot: snapAfter,
        httpClient: _httpClient(
          forYouResponse: http.Response(
            jsonEncode({
              'profileHash': 'stale-profile-hash',
              'items': [
                {
                  'seriesId': 'labubu_other',
                  'reasonType': RecommendationReasonType.newInCatalog,
                },
              ],
            }),
            200,
          ),
        ),
        preferences: prefs,
      );
      final after = await repoAfter.getRecommendations(_installId, _nommiBundle());

      expect(
        after.items.map((item) => item.seriesId),
        contains('nommi_reco'),
      );
      expect(
        after.items
            .where((item) => item.seriesId == 'nommi_reco')
            .first
            .primaryReasonType,
        RecommendationReasonType.trackedIp,
      );
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
                'reasonType': RecommendationReasonType.trackedIp,
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
