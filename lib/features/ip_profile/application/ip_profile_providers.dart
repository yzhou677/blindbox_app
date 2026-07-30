import 'package:blindbox_app/features/ip_profile/data/ip_profile_repository.dart';
import 'package:blindbox_app/features/ip_profile/domain/ip_introduction_profile.dart';
import 'package:blindbox_app/features/ip_profile/domain/ip_profile_cache_policy.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final ipProfileRepositoryProvider = Provider<IpProfileRepository>(
  (ref) => FirestoreIpProfileRepository.shared(),
);

/// Bumped on Discover pull-to-refresh and offline→online recovery.
///
/// Active [ipIntroductionProfileProvider] watchers re-run; inactive IPs stay
/// lazy until their UI mounts again (autoDispose). Fetch mode stays
/// cache-first — the repository honors per-entry `needsRevalidation`.
final ipProfileRevalidationEpochProvider = StateProvider<int>((ref) => 0);

/// Cached rich profile for a stable catalog [ipId] (`ip_profiles/{ipId}`).
///
/// Family key must be the taxonomy/catalog id — never a display name.
/// Missing / malformed / exhausted transient failure without a prior valid
/// profile → `null` (Discover hides the info icon). Last valid profile is
/// preserved across failed revalidation.
final ipIntroductionProfileProvider = FutureProvider.autoDispose
    .family<IpIntroductionProfile?, String>((ref, ipId) async {
      final id = ipId.trim();
      if (id.isEmpty) return null;

      // Dependency only — triggers re-run for currently watched ipIds.
      ref.watch(ipProfileRevalidationEpochProvider);

      final repo = ref.watch(ipProfileRepositoryProvider);
      return repo.fetchByIpId(id, mode: IpProfileFetchMode.cacheFirst);
    });
