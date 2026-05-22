import 'package:blindbox_app/models/market_listing.dart';
import 'package:flutter/material.dart';

/// Editorial shelf signals — calm, collectible-native (not a trading strip).
class ListingMarketSignals extends StatelessWidget {
  const ListingMarketSignals({super.key, required this.listing, this.dense = false});

  final MarketListing listing;
  final bool dense;

  static const int _maxChips = 1;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final chips = _buildSignals();

    if (chips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(top: dense ? 4 : 6, bottom: dense ? 2 : 6),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          for (final c in chips)
            _SignalPill(
              text: c.text,
              scheme: scheme,
              textTheme: textTheme,
              emphasis: c.emphasis,
            ),
        ],
      ),
    );
  }

  List<({String text, _SignalEmphasis emphasis})> _buildSignals() {
    final m = listing;
    final q = <({String text, _SignalEmphasis emphasis})>[];

    if (m.hasSecretFigure) {
      q.add((text: 'Secret', emphasis: _SignalEmphasis.soft));
    }
    if (m.isHardToFind) {
      q.add((text: 'Hard to find', emphasis: _SignalEmphasis.warm));
    }
    if (m.isTrending) {
      q.add((text: 'Trending', emphasis: _SignalEmphasis.soft));
    }

    return q.length > _maxChips ? q.sublist(0, _maxChips) : q;
  }
}

enum _SignalEmphasis { neutral, soft, warm }

class _SignalPill extends StatelessWidget {
  const _SignalPill({
    required this.text,
    required this.scheme,
    required this.textTheme,
    required this.emphasis,
  });

  final String text;
  final ColorScheme scheme;
  final TextTheme textTheme;
  final _SignalEmphasis emphasis;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color border, Color fg) = switch (emphasis) {
      _SignalEmphasis.warm => (
          Color.lerp(
                scheme.secondaryContainer,
                scheme.primaryContainer,
                0.35,
              )!
              .withValues(alpha: 0.44),
          Color.lerp(scheme.secondary, scheme.primary, 0.25)!.withValues(alpha: 0.22),
          scheme.onSecondaryContainer.withValues(alpha: 0.88),
        ),
      _SignalEmphasis.soft => (
          scheme.primary.withValues(alpha: 0.09),
          scheme.primary.withValues(alpha: 0.2),
          scheme.primary.withValues(alpha: 0.86),
        ),
      _SignalEmphasis.neutral => (
          scheme.surfaceContainerHighest.withValues(alpha: 0.52),
          scheme.outlineVariant.withValues(alpha: 0.32),
          scheme.onSurfaceVariant.withValues(alpha: 0.88),
        ),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          text,
          style: textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w500,
            letterSpacing: 0.06,
            height: 1.1,
            color: fg,
          ),
        ),
      ),
    );
  }
}
