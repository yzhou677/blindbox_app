import 'dart:async';

import 'package:blindbox_app/core/network/app_network_recovery.dart';
import 'package:blindbox_app/features/catalog/application/catalog_bundle_cache.dart';
import 'package:blindbox_app/features/catalog/catalog_bundle.dart';
import 'package:blindbox_app/features/ip_profile/application/ip_profile_providers.dart';
import 'package:blindbox_app/features/ip_profile/data/ip_profile_cache_store.dart';
import 'package:blindbox_app/features/ip_profile/data/ip_profile_document_source.dart';
import 'package:blindbox_app/features/ip_profile/data/ip_profile_repository.dart';
import 'package:blindbox_app/features/ip_profile/domain/ip_introduction_profile.dart';
import 'package:blindbox_app/features/official_feed/application/official_feed_providers.dart';
import 'package:blindbox_app/features/official_feed/domain/official_feed_catalog.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _profile = IpIntroductionProfile(
  ipId: 'molly',
  displayName: 'MOLLY',
  shortDescription: 'A cheerful fashion icon.',
  styleTags: ['Fashion', 'Playful', 'Iconic'],
);

Map<String, dynamic> _validData() => {
  'displayName': 'MOLLY',
  'shortDescription': 'A cheerful fashion icon.',
  'styleTags': ['Fashion', 'Playful', 'Iconic'],
};

class _CountingSource implements IpProfileDocumentSource {
  final Map<String, List<Object>> queues;
  final Map<String, int> calls = {};

  _CountingSource(this.queues);

  @override
  Future<IpProfileRemoteDocument> fetch(
    String ipId, {
    required bool preferServer,
  }) async {
    calls[ipId] = (calls[ipId] ?? 0) + 1;
    final q = queues[ipId];
    if (q == null || q.isEmpty) {
      throw FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');
    }
    final next = q.removeAt(0);
    if (next is Exception) throw next;
    return next as IpProfileRemoteDocument;
  }
}

List<Override> _discoverOverrides(IpProfileRepository repo) => [
  ipProfileRepositoryProvider.overrideWithValue(repo),
  officialFeedCatalogProvider.overrideWith(
    (_) async => OfficialFeedCatalog.empty,
  ),
];

void main() {
  tearDown(() {
    AppNetworkRecoveryNotifier.debugConnectivityStream = null;
    AppNetworkRecoveryNotifier.debugConnectivityCheck = null;
    AppNetworkRecoveryNotifier.debugClock = null;
    FirestoreIpProfileRepository.debugClearCache();
    CatalogBundleCache.resetForTest();
  });

  setUp(() {
    CatalogBundleCache.persistOverride = (_) async {};
    CatalogBundleCache.prime(
      const CatalogSeedBundle(brands: [], ips: [], series: [], figures: []),
    );
    CatalogBundleCache.setLastFirestoreRefreshAtForTest(DateTime.now());
    CatalogBundleCache.loadFirestoreOverride = () async =>
        const CatalogSeedBundle(brands: [], ips: [], series: [], figures: []);
  });

  test('offline-to-online retries currently watched failed profile', () async {
    final connectivity = StreamController<List<ConnectivityResult>>.broadcast();
    addTearDown(connectivity.close);

    var now = DateTime.utc(2026, 7, 29, 12);
    AppNetworkRecoveryNotifier.debugClock = () => now;
    AppNetworkRecoveryNotifier.debugConnectivityStream = () =>
        connectivity.stream;
    AppNetworkRecoveryNotifier.debugConnectivityCheck = () async => [
      ConnectivityResult.none,
    ];

    final source = _CountingSource({
      'molly': [
        FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
        FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
        FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
        IpProfileRemoteDocument(
          documentId: 'molly',
          exists: true,
          isFromCache: false,
          data: _validData(),
        ),
      ],
    });
    final cache = IpProfileCacheStore(clock: () => now);
    final repo = FirestoreIpProfileRepository(
      source: source,
      cache: cache,
      clock: () => now,
      delay: (_) async {},
    );

    final container = ProviderContainer(overrides: _discoverOverrides(repo));
    addTearDown(container.dispose);
    container.read(appNetworkRecoveryProvider);

    final sub = container.listen(
      ipIntroductionProfileProvider('molly'),
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(sub.close);

    await pumpEventQueue();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await pumpEventQueue();

    expect(
      container.read(ipIntroductionProfileProvider('molly')).asData?.value,
      isNull,
    );
    expect(source.calls['molly'], 3);

    connectivity.add([ConnectivityResult.wifi]);
    now = now.add(kNetworkRecoveryDebounce + const Duration(milliseconds: 50));
    await Future<void>.delayed(
      kNetworkRecoveryDebounce + const Duration(milliseconds: 100),
    );
    await pumpEventQueue();

    final recovered = container.read(ipIntroductionProfileProvider('molly'));
    expect(recovered.asData?.value?.ipId, 'molly');
    expect(source.calls['molly'], 4);
  });

  test('reconnect does not fetch inactive IPs eagerly', () async {
    final connectivity = StreamController<List<ConnectivityResult>>.broadcast();
    addTearDown(connectivity.close);

    var now = DateTime.utc(2026, 7, 29, 12);
    AppNetworkRecoveryNotifier.debugClock = () => now;
    AppNetworkRecoveryNotifier.debugConnectivityStream = () =>
        connectivity.stream;
    AppNetworkRecoveryNotifier.debugConnectivityCheck = () async => [
      ConnectivityResult.none,
    ];

    final source = _CountingSource({
      'molly': [
        FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
        FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
        FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
      ],
      'hirono': [
        FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
        FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
        FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
      ],
    });
    final repo = FirestoreIpProfileRepository(
      source: source,
      cache: IpProfileCacheStore(clock: () => now),
      clock: () => now,
      delay: (_) async {},
    );

    final container = ProviderContainer(overrides: _discoverOverrides(repo));
    addTearDown(container.dispose);
    container.read(appNetworkRecoveryProvider);

    await container.read(ipIntroductionProfileProvider('molly').future);
    await container.read(ipIntroductionProfileProvider('hirono').future);
    await pumpEventQueue();

    final mollyCalls = source.calls['molly']!;
    final hironoCalls = source.calls['hirono']!;

    connectivity.add([ConnectivityResult.wifi]);
    now = now.add(kNetworkRecoveryDebounce + const Duration(milliseconds: 50));
    await Future<void>.delayed(
      kNetworkRecoveryDebounce + const Duration(milliseconds: 100),
    );
    await pumpEventQueue();

    expect(source.calls['molly'], mollyCalls);
    expect(source.calls['hirono'], hironoCalls);
  });

  test('repeated identical online events do not storm refreshes', () async {
    final connectivity = StreamController<List<ConnectivityResult>>.broadcast();
    addTearDown(connectivity.close);

    var now = DateTime.utc(2026, 7, 29, 12);
    var bumps = 0;
    AppNetworkRecoveryNotifier.debugClock = () => now;
    AppNetworkRecoveryNotifier.debugConnectivityStream = () =>
        connectivity.stream;
    AppNetworkRecoveryNotifier.debugConnectivityCheck = () async => [
      ConnectivityResult.wifi,
    ];

    final repo = MemoryIpProfileRepository({'molly': _profile});
    final container = ProviderContainer(overrides: _discoverOverrides(repo));
    addTearDown(container.dispose);
    container.read(appNetworkRecoveryProvider);
    container.listen(ipProfileRevalidationEpochProvider, (prev, next) {
      if (prev != next) bumps++;
    });

    connectivity.add([ConnectivityResult.wifi]);
    connectivity.add([ConnectivityResult.wifi]);
    await Future<void>.delayed(
      kNetworkRecoveryDebounce + const Duration(milliseconds: 100),
    );
    expect(bumps, 0);

    connectivity.add([ConnectivityResult.none]);
    connectivity.add([ConnectivityResult.wifi]);
    now = now.add(kNetworkRecoveryDebounce + const Duration(milliseconds: 20));
    await Future<void>.delayed(
      kNetworkRecoveryDebounce + const Duration(milliseconds: 100),
    );
    expect(bumps, 1);

    connectivity.add([ConnectivityResult.none]);
    connectivity.add([ConnectivityResult.wifi]);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(bumps, 1);
  });

  test('reconnect plus resume coalesce into one recovery', () async {
    final connectivity = StreamController<List<ConnectivityResult>>.broadcast();
    addTearDown(connectivity.close);

    var now = DateTime.utc(2026, 7, 29, 12);
    AppNetworkRecoveryNotifier.debugClock = () => now;
    AppNetworkRecoveryNotifier.debugConnectivityStream = () =>
        connectivity.stream;
    AppNetworkRecoveryNotifier.debugConnectivityCheck = () async => [
      ConnectivityResult.wifi,
    ];

    final repo = MemoryIpProfileRepository({'molly': _profile});
    final container = ProviderContainer(overrides: _discoverOverrides(repo));
    addTearDown(container.dispose);
    final notifier = container.read(appNetworkRecoveryProvider.notifier);

    connectivity.add([ConnectivityResult.none]);
    connectivity.add([ConnectivityResult.wifi]);
    notifier.onAppResumed();

    now = now.add(kNetworkRecoveryDebounce + const Duration(milliseconds: 20));
    await Future<void>.delayed(
      kNetworkRecoveryDebounce + const Duration(milliseconds: 120),
    );

    expect(container.read(ipProfileRevalidationEpochProvider), 1);
  });

  test('joining network without internet does not loop forever', () async {
    final connectivity = StreamController<List<ConnectivityResult>>.broadcast();
    addTearDown(connectivity.close);

    var now = DateTime.utc(2026, 7, 29, 12);
    AppNetworkRecoveryNotifier.debugClock = () => now;
    AppNetworkRecoveryNotifier.debugConnectivityStream = () =>
        connectivity.stream;
    AppNetworkRecoveryNotifier.debugConnectivityCheck = () async => [
      ConnectivityResult.none,
    ];

    final source = _CountingSource({
      'molly': [
        for (var i = 0; i < 9; i++)
          FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
      ],
    });
    final repo = FirestoreIpProfileRepository(
      source: source,
      cache: IpProfileCacheStore(clock: () => now),
      clock: () => now,
      delay: (_) async {},
    );
    final container = ProviderContainer(overrides: _discoverOverrides(repo));
    addTearDown(container.dispose);
    container.read(appNetworkRecoveryProvider);

    final sub = container.listen(
      ipIntroductionProfileProvider('molly'),
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(sub.close);
    await pumpEventQueue();

    connectivity.add([ConnectivityResult.wifi]);
    now = now.add(kNetworkRecoveryDebounce + const Duration(milliseconds: 20));
    await Future<void>.delayed(
      kNetworkRecoveryDebounce + const Duration(milliseconds: 100),
    );
    await pumpEventQueue();

    final callsAfterReconnect = source.calls['molly'] ?? 0;
    expect(callsAfterReconnect, lessThanOrEqualTo(6));

    now = now.add(const Duration(seconds: 5));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(source.calls['molly'], callsAfterReconnect);
  });
}
