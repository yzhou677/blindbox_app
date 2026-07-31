import 'package:blindbox_app/features/ip_profile/data/ip_profile_mapper.dart';
import 'package:blindbox_app/features/ip_profile/data/ip_profile_repository.dart';
import 'package:blindbox_app/features/ip_profile/domain/ip_introduction_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('mapIpIntroductionProfile', () {
    test('maps marketingDisplayName over displayName', () {
      final profile = mapIpIntroductionProfile(
        documentId: 'skullpanda',
        data: {
          'displayName': 'Skullpanda',
          'marketingDisplayName': 'SKULLPANDA',
          'shortDescription': 'A quiet surreal character.',
          'styleTags': ['Surreal', 'Introspective', 'Fashion'],
        },
      );
      expect(profile?.displayName, 'SKULLPANDA');
      expect(profile?.ipId, 'skullpanda');
      expect(profile?.styleTags, ['Surreal', 'Introspective', 'Fashion']);
    });

    test('requires exactly three style tags', () {
      expect(
        mapIpIntroductionProfile(
          documentId: 'skullpanda',
          data: {
            'displayName': 'SKULLPANDA',
            'shortDescription': 'Desc',
            'styleTags': ['A', 'B'],
          },
        ),
        isNull,
      );
    });

    test('omits creator when null or incomplete', () {
      final noCreator = mapIpIntroductionProfile(
        documentId: 'skullpanda',
        data: {
          'displayName': 'SKULLPANDA',
          'shortDescription': 'Desc',
          'styleTags': ['A', 'B', 'C'],
        },
      );
      expect(noCreator?.hasCreator, isFalse);

      final partial = mapIpIntroductionProfile(
        documentId: 'skullpanda',
        data: {
          'displayName': 'SKULLPANDA',
          'shortDescription': 'Desc',
          'styleTags': ['A', 'B', 'C'],
          'creator': {'displayName': 'XIONGMIAO'},
        },
      );
      expect(partial?.hasCreator, isFalse);
    });

    test('maps creator when name and bio present', () {
      final profile = mapIpIntroductionProfile(
        documentId: 'skullpanda',
        data: {
          'displayName': 'SKULLPANDA',
          'shortDescription': 'Desc',
          'styleTags': ['A', 'B', 'C'],
          'creator': {
            'displayName': 'XIONGMIAO',
            'bio': 'Artist and designer.',
          },
        },
      );
      expect(profile?.hasCreator, isTrue);
      expect(profile?.creatorDisplayName, 'XIONGMIAO');
    });

    test('never treats display name as document id', () {
      final profile = mapIpIntroductionProfile(
        documentId: 'the_monsters',
        data: {
          'displayName': 'THE MONSTERS',
          'shortDescription': 'Desc',
          'styleTags': ['A', 'B', 'C'],
        },
      );
      expect(profile?.ipId, 'the_monsters');
      expect(profile?.ipId, isNot(profile?.displayName));
    });
  });

  group('MemoryIpProfileRepository', () {
    test('lookup uses stable ipId only', () async {
      final repo = MemoryIpProfileRepository({
        'skullpanda': const IpIntroductionProfile(
          ipId: 'skullpanda',
          displayName: 'SKULLPANDA',
          shortDescription: 'Desc',
          styleTags: ['A', 'B', 'C'],
        ),
      });

      final byId = await repo.fetchByIpId('skullpanda');
      final byName = await repo.fetchByIpId('SKULLPANDA');
      expect(byId?.displayName, 'SKULLPANDA');
      expect(byName, isNull);
      expect(repo.requestedIds, ['skullpanda', 'SKULLPANDA']);
    });
  });
}
