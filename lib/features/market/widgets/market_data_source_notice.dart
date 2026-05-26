import 'package:blindbox_app/core/theme/collectible_tokens.dart';
import 'package:blindbox_app/features/market/data/gateway/market_gateway_config.dart';
import 'package:flutter/material.dart';

/// Quiet disclosure that Market browse is powered by eBay (or preview vs live).
class MarketDataSourceNotice extends StatelessWidget {
  const MarketDataSourceNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final tokens = CollectibleTokens.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final liveEbay = MarketGatewayConfig.isActive;

    final message = liveEbay
        ? 'Listings and prices on Market are sourced from eBay.'
        : 'Preview listings for layout. Live Market data comes from eBay.';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Color.lerp(
            scheme.surface,
            scheme.primaryContainer,
            isDark ? 0.12 : 0.18,
          )!.withValues(alpha: isDark ? 0.55 : 0.72),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: isDark ? 0.22 : 0.3),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.storefront_outlined,
                size: 18,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.62),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: tokens.supportiveBody(textTheme, scheme),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
