import 'package:blindbox_app/core/theme/app_spacing.dart';
import 'package:blindbox_app/features/market/data/gateway/market_gateway_config.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Quiet disclosure that Market browse is powered by eBay (or preview vs live).
class MarketDataSourceNotice extends StatelessWidget {
  const MarketDataSourceNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final liveEbay = MarketGatewayConfig.isActive;

    final message = liveEbay
        ? 'Listings and prices on Market are sourced from eBay.'
        : 'Preview listings for layout. Live Market data comes from eBay.';

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pageHorizontal,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Color.lerp(
            scheme.surface,
            scheme.primaryContainer,
            isDark ? 0.08 : 0.1,
          )!.withValues(alpha: isDark ? 0.38 : 0.42),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Symbols.storefront_rounded,
                size: 16,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.70),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: textTheme.bodySmall?.copyWith(
                    fontSize: 13,
                    height: 1.3,
                    fontWeight: FontWeight.w400,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.62),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
