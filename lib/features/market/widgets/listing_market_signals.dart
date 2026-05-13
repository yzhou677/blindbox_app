import 'package:blindbox_app/features/market/utils/market_format.dart';
import 'package:blindbox_app/models/market_demand_mood.dart';
import 'package:blindbox_app/models/market_listing.dart';
import 'package:flutter/material.dart';

/// eBay-adjacent shelf signals — soft, capped count, never a ticker.
class ListingMarketSignals extends StatelessWidget {
  const ListingMarketSignals({super.key, required this.listing, this.dense = false});

  final MarketListing listing;
  final bool dense;

  static const int _maxChips = 3;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final chips = _buildSignals();

    if (chips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(bottom: dense ? 6 : 8),
      child: Wrap(
        spacing: 6,
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
    final pct = m.priceChangePercent;
    final hot = m.isTrending && pct >= 3.0;
    final q = <({String text, _SignalEmphasis emphasis})>[];

    if (m.isRareFind) {
      q.add((text: 'Rare find', emphasis: _SignalEmphasis.warm));
    }
    if (hot) {
      q.add((text: '↑ Hot', emphasis: _SignalEmphasis.spark));
    } else if (m.isTrending) {
      q.add((text: 'Trending', emphasis: _SignalEmphasis.soft));
    }
    if (m.watchingCount >= 10) {
      q.add((text: '${m.watchingCount} watching', emphasis: _SignalEmphasis.neutral));
    }
    if (q.length < _maxChips && m.demandMood == MarketDemandMood.rising) {
      q.add((text: 'Demand rising', emphasis: _SignalEmphasis.soft));
    } else if (q.length < _maxChips &&
        m.demandMood == MarketDemandMood.steady &&
        m.watchingCount > 0 &&
        m.watchingCount < 10) {
      q.add((text: 'Steady interest', emphasis: _SignalEmphasis.neutral));
    }
    if (q.length < _maxChips && !hot && pct.abs() >= 1.2) {
      q.add((
        text: 'Last sale ${formatPriceChangePercent(pct)}',
        emphasis: _SignalEmphasis.neutral,
      ));
    }

    return q.length > _maxChips ? q.sublist(0, _maxChips) : q;
  }
}

enum _SignalEmphasis { neutral, soft, warm, spark }

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
      _SignalEmphasis.spark => (
          scheme.tertiary.withValues(alpha: 0.14),
          scheme.tertiary.withValues(alpha: 0.32),
          scheme.onSurface.withValues(alpha: 0.88),
        ),
      _SignalEmphasis.warm => (
          scheme.secondaryContainer.withValues(alpha: 0.42),
          scheme.secondary.withValues(alpha: 0.22),
          scheme.onSecondaryContainer.withValues(alpha: 0.88),
        ),
      _SignalEmphasis.soft => (
          scheme.primary.withValues(alpha: 0.1),
          scheme.primary.withValues(alpha: 0.22),
          scheme.primary.withValues(alpha: 0.88),
        ),
      _SignalEmphasis.neutral => (
          scheme.surfaceContainerHighest.withValues(alpha: 0.55),
          scheme.outlineVariant.withValues(alpha: 0.35),
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          text,
          style: textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.04,
            height: 1.1,
            color: fg,
          ),
        ),
      ),
    );
  }
}
