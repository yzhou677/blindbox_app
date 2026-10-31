import 'package:blindbox_app/features/ip_profile/data/ip_profile_document_source.dart';
import 'package:blindbox_app/features/ip_profile/data/ip_profile_repository.dart';
import 'package:blindbox_app/features/ip_profile/domain/ip_profile_cache_policy.dart';
import 'package:blindbox_app/features/ip_profile/data/ip_profile_fetch_error.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:blindbox_app/features/ip_profile/data/ip_profile_cache_store.dart';

IpProfileRemoteDocument _doc({
  required bool exists,
  bool fromCache = false,
  Map<String, dynamic>? data,
  String id = 'molly',
}) {
  return IpProfileRemoteDocument(
    documentId: id,
    exists: exists,
    isFromCache: fromCache,
    data: data,
  );
}

Map<String, dynamic> _validData() => {
  'displayName': 'MOLLY',
  'shortDescription': 'A cheerful fashion icon.',
  'styleTags': ['Fashion', 'Playful', 'Iconic'],
};

class _FakeSource implements IpProfileDocumentSource {
  _FakeSource(this.responses);

  final List<Object> responses;
  int calls = 0;
  final List<bool> preferServerFlags = [];

  @override
  Future<IpProfileRemoteDocument> fetch(
    String ipId, {
    required bool preferServer,
  }) async {
    preferServerFlags.add(preferServer);
    calls++;
    if (responses.isEmpty) {
      throw StateError('no responses left for $ipId');
    }
    final next = responses.removeAt(0);
    if (next is Exception) throw next;
    if (next is Error) throw next;
    return next as IpProfileRemoteDocument;
  }
}

void main() {
  late List<Duration> delays;
  late DateTime now;

  FirestoreIpProfileRepository repoFor(
    IpProfileDocumentSource source, {
    IpProfileCacheStore? cache,
  }) {
    delays = [];
    return FirestoreIpProfileRepository(
      source: source,
      cache: cache ?? IpProfileCacheStore(clock: () => now),
      clock: () => now,
      delay: (d) async {
        delays.add(d);
      },
    );
  }

  setUp(() {
    now = DateTime.utc(2026, 7, 29, 12);
    FirestoreIpProfileRepository.debugClearCache();
  });

  group('classifyIpProfileFailure', () {
    test('permission-denied is permanent', () {
      expect(
        classifyIpProfileFailure(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
          ),
        ),
        IpProfileFailureKind.permanent,
      );
    });

    test('unavailable is transient', () {
      expect(
        classifyIpProfileFailure(
          FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
        ),
        IpProfileFailureKind.transient,
      );
    });
  });

  group('retry', () {
    test(
      'transient failures attempt at most three times with backoff',
      () async {
        final source = _FakeSource([
          FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
          FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
          FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
        ]);
        final repo = repoFor(source);

        final result = await repo.fetchByIpId('molly');
        expect(result, isNull);
        expect(source.calls, 3);
        expect(delays, [
          IpProfileCachePolicy.backoffAfterAttempt1,
          IpProfileCachePolicy.backoffAfterAttempt2,
        ]);
        final entry = repo.debugCache['molly'];
        expect(entry?.hasRetryableFailure, isTrue);
        expect(entry?.missingConfirmedAt, isNull);
      },
    );

    test('succeeds on second attempt', () async {
      final source = _FakeSource([
        FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
        _doc(exists: true, data: _validData()),
      ]);
      final repo = repoFor(source);
      final result = await repo.fetchByIpId('molly');
      expect(result?.displayName, 'MOLLY');
      expect(source.calls, 2);
      expect(delays, [IpProfileCachePolicy.backoffAfterAttempt1]);
    });

    test('succeeds on third attempt', () async {
      final source = _FakeSource([
        FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
        FirebaseException(plugin: 'cloud_firestore', code: 'deadline-exceeded'),
        _doc(exists: true, data: _validData()),
      ]);
      final repo = repoFor(source);
      expect(await repo.fetchByIpId('molly'), isNotNull);
      expect(source.calls, 3);
    });

    test('permission-denied is not retried', () async {
      final source = _FakeSource([
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
      ]);
      final repo = repoFor(source);
      expect(await repo.fetchByIpId('molly'), isNull);
      expect(source.calls, 1);
      expect(delays, isEmpty);
      expect(repo.debugCache['molly']?.hasPermanentFailure, isTrue);
    });

    test('later request recovers after three transient failures', () async {
      final source = _FakeSource([
        FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
        FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
        FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
        _doc(exists: true, data: _validData()),
      ]);
      final repo = repoFor(source);
      expect(await repo.fetchByIpId('molly'), isNull);
      expect(source.calls, 3);

      // Soft-dirty from failure — next preferServer / revalidation retries.
      final recovered = await repo.fetchByIpId(
        'molly',
        mode: IpProfileFetchMode.preferServer,
      );
      expect(recovered?.ipId, 'molly');
      expect(source.calls, 4);
    });
  });

  group('cache outcomes', () {
    test('valid profile uses long success cache', () async {
      final source = _FakeSource([_doc(exists: true, data: _validData())]);
      final repo = repoFor(source);
      expect(await repo.fetchByIpId('molly'), isNotNull);
      expect(await repo.fetchByIpId('molly'), isNotNull);
      expect(source.calls, 1);

      now = now.add(IpProfileCachePolicy.successTtl - const Duration(hours: 1));
      expect(await repo.fetchByIpId('molly'), isNotNull);
      expect(source.calls, 1);

      now = now.add(const Duration(hours: 2));
      source.responses.add(_doc(exists: true, data: _validData()));
      expect(await repo.fetchByIpId('molly'), isNotNull);
      expect(source.calls, 2);
    });

    test('missing server document uses short negative cache', () async {
      final source = _FakeSource([_doc(exists: false, fromCache: false)]);
      final repo = repoFor(source);
      expect(await repo.fetchByIpId('molly'), isNull);
      expect(await repo.fetchByIpId('molly'), isNull);
      expect(source.calls, 1);

      now = now.add(
        IpProfileCachePolicy.missingTtl + const Duration(seconds: 1),
      );
      source.responses.add(_doc(exists: true, data: _validData()));
      expect(await repo.fetchByIpId('molly'), isNotNull);
      expect(source.calls, 2);
    });

    test('offline SDK-cache miss is not confirmed missing', () async {
      final source = _FakeSource([_doc(exists: false, fromCache: true)]);
      final repo = repoFor(source);
      expect(await repo.fetchByIpId('molly'), isNull);
      expect(repo.debugCache['molly']?.missingConfirmedAt, isNull);
      expect(repo.debugCache['molly']?.hasRetryableFailure, isTrue);
    });

    test('failed revalidation preserves last valid profile', () async {
      final source = _FakeSource([
        _doc(exists: true, data: _validData()),
        FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
        FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
        FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
      ]);
      final repo = repoFor(source);
      expect(await repo.fetchByIpId('molly'), isNotNull);
      repo.prepareForRevalidation();
      final still = await repo.fetchByIpId(
        'molly',
        mode: IpProfileFetchMode.preferServer,
      );
      expect(still?.displayName, 'MOLLY');
      expect(source.calls, 4);
    });

    test('remotely edited profile visible after targeted refresh', () async {
      final source = _FakeSource([
        _doc(exists: true, data: _validData()),
        _doc(
          exists: true,
          data: {
            'displayName': 'MOLLY',
            'shortDescription': 'Updated description for collectors.',
            'styleTags': ['Fashion', 'Playful', 'Iconic'],
          },
        ),
      ]);
      final repo = repoFor(source);
      expect(
        (await repo.fetchByIpId('molly'))?.shortDescription,
        'A cheerful fashion icon.',
      );
      repo.prepareForRevalidation();
      final updated = await repo.fetchByIpId(
        'molly',
        mode: IpProfileFetchMode.preferServer,
      );
      expect(updated?.shortDescription, 'Updated description for collectors.');
    });

    test('transient failure is not cached as missing', () async {
      final source = _FakeSource([
        FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
        FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
        FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
      ]);
      final repo = repoFor(source);
      await repo.fetchByIpId('molly');
      expect(repo.debugCache['molly']?.missingConfirmedAt, isNull);
    });

    test('display names are never used as cache keys', () async {
      final source = _FakeSource([_doc(exists: true, data: _validData())]);
      final repo = repoFor(source);
      await repo.fetchByIpId('molly');
      expect(repo.debugCache['MOLLY'], isNull);
      expect(repo.debugCache['molly'], isNotNull);
    });
  });

  group('in-flight coalescing', () {
    test('simultaneous same-ipId requests share one sequence', () async {
      var gateOpen = false;
      final source = _GateSource(
        () => gateOpen,
        _doc(exists: true, data: _validData()),
      );
      final repo = repoFor(source);

      final a = repo.fetchByIpId('molly');
      final b = repo.fetchByIpId('molly');
      expect(repo.debugInflight.containsKey('molly'), isTrue);
      gateOpen = true;
      final results = await Future.wait([a, b]);
      expect(results[0]?.ipId, 'molly');
      expect(results[1]?.ipId, 'molly');
      expect(source.calls, 1);
      expect(repo.debugInflight, isEmpty);
    });

    test('different ipIds remain independent', () async {
      final source = _MultiSource({
        'molly': [_doc(exists: true, data: _validData())],
        'hirono': [
          _doc(
            id: 'hirono',
            exists: true,
            data: {
              'displayName': 'Hirono',
              'shortDescription': 'Quiet wanderer.',
              'styleTags': ['Surreal', 'Soft', 'Poetic'],
            },
          ),
        ],
      });
      final repo = FirestoreIpProfileRepository(
        source: source,
        cache: IpProfileCacheStore(clock: () => now),
        clock: () => now,
        delay: (_) async {},
      );
      final results = await Future.wait([
        repo.fetchByIpId('molly'),
        repo.fetchByIpId('hirono'),
      ]);
      expect(results[0]?.ipId, 'molly');
      expect(results[1]?.ipId, 'hirono');
      expect(source.calls['molly'], 1);
      expect(source.calls['hirono'], 1);
    });
  });

  group('revalidation', () {
    test(
      'pull-to-refresh clears negative cache without eager N reads',
      () async {
        final source = _FakeSource([
          _doc(exists: false),
          _doc(exists: false, id: 'hirono'),
        ]);
        final repo = repoFor(source);
        await repo.fetchByIpId('molly');
        await repo.fetchByIpId('hirono');
        expect(source.calls, 2);

        repo.prepareForRevalidation();
        expect(repo.debugCache['molly']?.missingConfirmedAt, isNull);
        expect(repo.debugCache['hirono']?.missingConfirmedAt, isNull);
        // No automatic fetches for inactive entries.
        expect(source.calls, 2);
      },
    );

    test('reconnect makes newly added profile discoverable', () async {
      final source = _FakeSource([
        _doc(exists: false),
        _doc(exists: true, data: _validData()),
      ]);
      final repo = repoFor(source);
      expect(await repo.fetchByIpId('molly'), isNull);
      repo.prepareForRevalidation();
      expect(await repo.fetchByIpId('molly'), isNotNull);
    });
  });
}

class _GateSource implements IpProfileDocumentSource {
  _GateSource(this.isOpen, this.doc);
  final bool Function() isOpen;
  final IpProfileRemoteDocument doc;
  int calls = 0;

  @override
  Future<IpProfileRemoteDocument> fetch(
    String ipId, {
    required bool preferServer,
  }) async {
    calls++;
    while (!isOpen()) {
      await Future<void>.delayed(Duration.zero);
    }
    return doc;
  }
}

class _MultiSource implements IpProfileDocumentSource {
  _MultiSource(this.queues);
  final Map<String, List<Object>> queues;
  final Map<String, int> calls = {};

  @override
  Future<IpProfileRemoteDocument> fetch(
    String ipId, {
    required bool preferServer,
  }) async {
    calls[ipId] = (calls[ipId] ?? 0) + 1;
    final q = queues[ipId]!;
    return q.removeAt(0) as IpProfileRemoteDocument;
  }
}
