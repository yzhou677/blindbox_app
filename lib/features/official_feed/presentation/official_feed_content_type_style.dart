import 'package:blindbox_app/features/official_feed/domain/official_feed_item.dart';
import 'package:blindbox_app/features/official_feed/presentation/official_feed_content_type.dart';
import 'package:flutter/material.dart';

/// Resolved tint + icon for one content-type deck label.
@immutable
class OfficialFeedContentTypeStyle {
  const OfficialFeedContentTypeStyle({
    required this.label,
    required this.background,
    required this.foreground,
    this.icon,
  });

  final String label;
  final Color background;
  final Color foreground;
  final IconData? icon;
}

@immutable
class _AccentSpec {
  const _AccentSpec(this.light, this.dark, {this.icon});

  final Color light;
  final Color dark;
  final IconData? icon;
}

/// Presentation-only palette — soft tints, not saturated badges.
abstract final class OfficialFeedContentTypeStyles {
  OfficialFeedContentTypeStyles._();

  static const _neutral = _AccentSpec(
    Color(0xFF8E9199),
    Color(0xFF9AA0A8),
    icon: Icons.article_outlined,
  );

  static const Map<String, _AccentSpec> _byLabel = {
    'Announcement': _AccentSpec(
      Color(0xFF6B8FC7),
      Color(0xFF8AA8D8),
      icon: Icons.campaign_outlined,
    ),
    'POP NOW': _AccentSpec(
      Color(0xFFE07A7A),
      Color(0xFFE89595),
      icon: Icons.bolt_outlined,
    ),
    'Collaboration': _AccentSpec(
      Color(0xFF9B7BB8),
      Color(0xFFB095CC),
      icon: Icons.auto_awesome_outlined,
    ),
    'Product Spotlight': _AccentSpec(
      Color(0xFFC4A574),
      Color(0xFFD4B88A),
      icon: Icons.star_outline_rounded,
    ),
    'Restock': _AccentSpec(
      Color(0xFFD49A6A),
      Color(0xFFE0AD82),
      icon: Icons.inventory_2_outlined,
    ),
    'Event': _AccentSpec(
      Color(0xFF6FA87A),
      Color(0xFF89BA92),
      icon: Icons.event_outlined,
    ),
    'Campaign': _AccentSpec(
      Color(0xFFB8889E),
      Color(0xFFC9A0B2),
      icon: Icons.flag_outlined,
    ),
    'Launch Reminder': _AccentSpec(
      Color(0xFFC9A227),
      Color(0xFFD9B44A),
      icon: Icons.notifications_none_outlined,
    ),
    'Limited Release': _AccentSpec(
      Color(0xFFB89B7A),
      Color(0xFFC9AE8F),
      icon: Icons.diamond_outlined,
    ),
    'Giveaway': _AccentSpec(
      Color(0xFFD4849A),
      Color(0xFFE09AAD),
      icon: Icons.card_giftcard_outlined,
    ),
    'Store Opening': _AccentSpec(
      Color(0xFF7A9E9E),
      Color(0xFF92B0B0),
      icon: Icons.storefront_outlined,
    ),
  };

  static OfficialFeedContentTypeStyle resolve(
    String label,
    ColorScheme scheme, {
    required bool isDark,
  }) {
    final spec = _byLabel[label] ?? _neutral;
    final accent = isDark ? spec.dark : spec.light;
    final base = isDark ? scheme.surfaceContainerHigh : scheme.surfaceContainerHighest;

    return OfficialFeedContentTypeStyle(
      label: label,
      background: Color.alphaBlend(
        accent.withValues(alpha: isDark ? 0.14 : 0.11),
        base,
      ),
      foreground: Color.lerp(
        scheme.onSurfaceVariant,
        accent,
        isDark ? 0.72 : 0.68,
      )!,
      icon: spec.icon,
    );
  }

  static OfficialFeedContentTypeStyle forItem(
    OfficialFeedItem item,
    ColorScheme scheme, {
    required bool isDark,
  }) {
    return resolve(inferOfficialFeedContentTypeLabel(item), scheme, isDark: isDark);
  }
}
