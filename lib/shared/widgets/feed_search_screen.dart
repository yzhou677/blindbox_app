import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/theme/app_spacing.dart';
import 'package:blindbox_app/core/theme/collectible_typography.dart';
import 'package:blindbox_app/shared/widgets/app_search_field.dart';
import 'package:flutter/material.dart';

/// Full-screen search shell shared by Discover catalog browse and Market browse.
///
/// ## Intentional deviations from the main-tab AppBar style
///
/// * `toolbarHeight: 72` — search overlays use a taller AppBar than main tabs
///   (52) to give the headline-sized title more vertical breathing room and to
///   visually distinguish the search context from a regular tab screen.
/// * Title style: [CollectibleTypography.editorialScreenTitle] (headlineSmall
///   w700) instead of the main-tab [textTheme.titleLarge] — the larger size
///   reinforces that this is a focused search mode, not a browsing tab.
/// * `top: FeedRhythm.headerToSearchField + 4` (18 vs 14) — an extra 4 px
///   compensates for the taller AppBar so the search field sits at the same
///   visual distance from the top of the content area as on the browse tabs.
///
/// Do NOT flatten these values to match main-tab constants; the differences
/// are intentional UX decisions, not inconsistencies.
class FeedSearchScreen extends StatelessWidget {
  const FeedSearchScreen({
    super.key,
    required this.title,
    required this.hintText,
    required this.emptyPrompt,
    required this.controller,
    required this.hasSearchText,
    required this.results,
    this.onChanged,
    this.onClear,
    this.onBack,
  });

  final String title;
  final String hintText;
  final String emptyPrompt;
  final TextEditingController controller;
  final bool hasSearchText;
  final Widget results;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;

  /// When set, replaces the default [Navigator.maybePop] (e.g. Market search exit).
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLow,
      appBar: AppBar(
        toolbarHeight: 72, // Intentional — see class-level doc above
        centerTitle: false,
        titleSpacing: AppSpacing.pageHorizontal,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (onBack != null) {
              onBack!();
            } else {
              Navigator.of(context).maybePop();
            }
          },
        ),
        title: Text(
          title,
          style: CollectibleTypography.editorialScreenTitle(
            textTheme,
            scheme,
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              top: FeedRhythm.headerToSearchField + 4,
            ),
            child: AppSearchField(
              controller: controller,
              autofocus: true,
              hintText: hintText,
              onChanged: onChanged,
              suffixIcon: !hasSearchText || onClear == null
                  ? null
                  : IconButton(
                      tooltip: 'Clear',
                      icon: Icon(
                        Icons.close_rounded,
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                      onPressed: onClear,
                    ),
            ),
          ),
          if (hasSearchText)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageHorizontal,
                AppSpacing.lg,
                AppSpacing.pageHorizontal,
                AppSpacing.sm,
              ),
              child: Text(
                'Matches',
                style: textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.12,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.88),
                ),
              ),
            ),
          Expanded(
            child: hasSearchText
                ? results
                : Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.emptyStateHorizontal,
                      ),
                      child: Text(
                        emptyPrompt,
                        textAlign: TextAlign.center,
                        style: textTheme.bodyLarge?.copyWith(
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.82),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
