import 'package:blindbox_app/features/sharing/presentation/share_card_preview.dart';
import 'package:blindbox_app/features/sharing/presentation/widgets/shelfy_collector_cards.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('calculateShareCardPreviewMetrics', () {
    test('keeps the preview within a compact phone viewport', () {
      final metrics = calculateShareCardPreviewMetrics(
        viewportSize: const Size(360, 640),
        viewPadding: const EdgeInsets.only(top: 24, bottom: 24),
      );

      expect(metrics.occupiedViewportHeight, lessThanOrEqualTo(640));
      expect(metrics.cardSize.aspectRatio, closeTo(_cardAspectRatio, 0.001));
      expect(metrics.cardSize.width, lessThanOrEqualTo(324));
    });

    test('uses horizontal space on the current Android device shape', () {
      final metrics = calculateShareCardPreviewMetrics(
        viewportSize: const Size(393, 851),
        viewPadding: const EdgeInsets.only(top: 32, bottom: 24),
      );

      expect(metrics.occupiedViewportHeight, lessThanOrEqualTo(851));
      expect(metrics.cardSize.aspectRatio, closeTo(_cardAspectRatio, 0.001));
      expect(metrics.cardSize.width, closeTo(357, 0.1));
    });

    test('does not make the sheet taller than a tall phone viewport', () {
      final metrics = calculateShareCardPreviewMetrics(
        viewportSize: const Size(430, 932),
        viewPadding: const EdgeInsets.only(top: 47, bottom: 34),
      );

      expect(metrics.occupiedViewportHeight, lessThanOrEqualTo(932));
      expect(metrics.cardSize.aspectRatio, closeTo(_cardAspectRatio, 0.001));
      expect(metrics.cardSize.width, closeTo(394, 0.1));
    });

    test('preserves the button and safe area before shrinking the card', () {
      final metrics = calculateShareCardPreviewMetrics(
        viewportSize: const Size(360, 568),
        viewPadding: const EdgeInsets.only(top: 24, bottom: 16),
      );

      expect(metrics.occupiedViewportHeight, lessThanOrEqualTo(568));
      expect(metrics.cardSize.aspectRatio, closeTo(_cardAspectRatio, 0.001));
      expect(metrics.cardSize.height, lessThan(500));
    });
  });
}

final _cardAspectRatio =
    kShelfyShareCardLogicalSize.width / kShelfyShareCardLogicalSize.height;
