import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/theme/collectible_typography.dart';
import 'package:blindbox_app/shared/widgets/app_search_field.dart';
import 'package:flutter/material.dart';

/// Full-screen search shell shared by Discover catalog browse and Market browse.
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
  });

  final String title;
  final String hintText;
  final String emptyPrompt;
  final TextEditingController controller;
  final bool hasSearchText;
  final Widget results;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLow,
      appBar: AppBar(
        toolbarHeight: 72,
        centerTitle: false,
        titleSpacing: 20,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
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
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
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
                      padding: const EdgeInsets.symmetric(horizontal: 28),
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
