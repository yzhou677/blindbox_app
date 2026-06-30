import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/theme/app_radii.dart';
import 'package:blindbox_app/features/catalog/application/catalog_availability.dart';
import 'package:blindbox_app/features/catalog/presentation/catalog_availability_copy.dart';
import 'package:flutter/material.dart';

/// Inline Material 3 card for catalog loading / offline states.
class CatalogAvailabilityCard extends StatelessWidget {
  const CatalogAvailabilityCard({
    super.key,
    required this.availability,
    this.onRetry,
    this.compact = false,
  });

  final CatalogAvailability availability;
  final VoidCallback? onRetry;

  /// Tighter padding for sheet / search result slots.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final state = availability.state;

    if (state == CatalogAvailabilityUiState.ready) {
      return const SizedBox.shrink();
    }

    final isLoading = state == CatalogAvailabilityUiState.loading;
    final title = isLoading
        ? CatalogAvailabilityCopy.loadingTitle
        : CatalogAvailabilityCopy.offlineTitle;
    final body = isLoading
        ? CatalogAvailabilityCopy.loadingBody
        : CatalogAvailabilityCopy.offlineBody;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 20),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: AppRadii.insetRadius,
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            compact ? 16 : 20,
            compact ? 20 : 24,
            compact ? 16 : 20,
            compact ? 20 : 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading)
                Padding(
                  padding: const EdgeInsets.only(bottom: FeedRhythm.sectionHeaderToRail),
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: scheme.primary,
                    ),
                  ),
                ),
              Text(
                title,
                textAlign: TextAlign.center,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                body,
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.88),
                  height: 1.4,
                ),
              ),
              if (!isLoading && onRetry != null) ...[
                const SizedBox(height: 16),
                FilledButton.tonal(
                  onPressed: onRetry,
                  child: const Text(CatalogAvailabilityCopy.retryLabel),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Centered message for search result panels when catalog is not usable.
class CatalogAvailabilitySearchMessage extends StatelessWidget {
  const CatalogAvailabilitySearchMessage({
    super.key,
    required this.message,
    this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.88),
                height: 1.4,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: onRetry,
                child: const Text(CatalogAvailabilityCopy.retryLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
