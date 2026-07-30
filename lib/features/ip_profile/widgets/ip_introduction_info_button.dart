import 'package:blindbox_app/core/theme/app_spacing.dart';
import 'package:blindbox_app/features/home/domain/series_release.dart';
import 'package:blindbox_app/features/ip_profile/application/ip_profile_providers.dart';
import 'package:blindbox_app/features/ip_profile/domain/ip_introduction_profile.dart';
import 'package:blindbox_app/features/ip_profile/widgets/ip_introduction_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Quiet info control beside an IP name — opens [showIpIntroductionSheet].
///
/// Used on Discover Series detail. Hidden while loading / on missing /
/// malformed / failed profiles.
class IpIntroductionInfoButton extends ConsumerWidget {
  const IpIntroductionInfoButton({
    super.key,
    required this.release,
    required this.ipDisplayName,
  });

  final SeriesRelease release;
  final String ipDisplayName;

  /// Visible glyph — quiet metadata, not a primary action.
  static const double visualIconSize = 16;

  /// Layout slot so the invisible 48dp hit area does not inflate row height.
  static const double layoutSlot = 18;

  /// Accessible tap target (expands via [OverflowBox] without shifting layout).
  static const double tapTarget = 48;

  /// Gap from the IP name text to the glyph.
  static const double nameGap = AppSpacing.xs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ipId = release.taxonomyIpId?.trim() ?? '';
    if (ipId.isEmpty) return const SizedBox.shrink();

    final async = ref.watch(ipIntroductionProfileProvider(ipId));
    final profile = async.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      data: (value) => value,
      loading: () => null,
      error: (_, _) => null,
    );
    if (profile == null || !profile.isValidForIntroduction) {
      return const SizedBox.shrink();
    }

    final scheme = Theme.of(context).colorScheme;
    final label = ipDisplayName.trim().isEmpty
        ? profile.displayName
        : ipDisplayName.trim();

    return Padding(
      padding: const EdgeInsets.only(left: nameGap),
      child: SizedBox(
        width: layoutSlot,
        height: layoutSlot,
        child: OverflowBox(
          minWidth: tapTarget,
          maxWidth: tapTarget,
          minHeight: tapTarget,
          maxHeight: tapTarget,
          alignment: Alignment.center,
          child: IconButton(
            key: Key('ip_introduction_info_$ipId'),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: tapTarget,
              minHeight: tapTarget,
            ),
            visualDensity: VisualDensity.compact,
            tooltip: 'About $label',
            onPressed: () {
              showIpIntroductionSheet(
                context: context,
                profile: profile,
                release: release,
              );
            },
            icon: Semantics(
              button: true,
              label: 'About $label',
              child: Icon(
                Symbols.info_rounded,
                size: visualIconSize,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.48),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Whether [profile] should reveal the Discover info affordance.
bool ipIntroductionInfoVisible(IpIntroductionProfile? profile) =>
    profile != null && profile.isValidForIntroduction;
