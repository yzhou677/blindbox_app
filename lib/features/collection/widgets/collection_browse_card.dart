import 'package:blindbox_app/core/theme/app_radii.dart';
import 'package:blindbox_app/core/theme/collectible_elevation.dart';
import 'package:blindbox_app/core/theme/collectible_typography.dart';
import 'package:blindbox_app/features/collection/presentation/collection_card_tokens.dart';
import 'package:flutter/material.dart';

/// Shared Collection browse-card shell.
///
/// This owns the card family chrome: dimensions, padding, image placement,
/// title/meta spacing, rounded corners, border, elevation, and overlay slot.
/// Surface-specific cards provide the image and footer content.
class CollectionBrowseCard extends StatelessWidget {
  const CollectionBrowseCard({
    super.key,
    required this.title,
    required this.image,
    required this.onTap,
    this.subtitle,
    this.footer,
    this.onLongPress,
    this.overlayBuilder,
    this.width = CollectionCardTokens.width,
    this.height = CollectionCardTokens.minRailHeight,
    this.padding = CollectionCardTokens.padding,
    this.imageExtent,
    this.imageToTitleGap = CollectionCardTokens.imageToTitleGap,
    this.titleToMetaGap = CollectionCardTokens.titleToMetaGap,
    this.metaToFooterGap = CollectionCardTokens.metaToProgressGap,
    this.titleMaxLines = 2,
    this.subtitleMaxLines = 1,
    this.titleStyle,
    this.subtitleStyle,
    this.borderColor,
    this.showPressedOverlay = false,
  });

  final String title;
  final String? subtitle;
  final Widget image;
  final Widget? footer;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final WidgetBuilder? overlayBuilder;
  final double width;
  final double height;
  final EdgeInsetsGeometry padding;
  final double? imageExtent;
  final double imageToTitleGap;
  final double titleToMetaGap;
  final double metaToFooterGap;
  final int titleMaxLines;
  final int subtitleMaxLines;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;
  final Color? borderColor;
  final bool showPressedOverlay;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final resolvedBorderColor =
        borderColor ??
        scheme.outlineVariant.withValues(alpha: isDark ? 0.32 : 0.38);
    final resolvedImageExtent =
        imageExtent ?? CollectionCardTokens.coverExtent;

    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: AppRadii.cardRadius,
          boxShadow: CollectibleElevation.softCard(context),
        ),
        child: Material(
          color: scheme.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadii.cardRadius,
            side: BorderSide(color: resolvedBorderColor),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              InkWell(
                onTap: onTap,
                onLongPress: onLongPress,
                child: Padding(
                  padding: padding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: ClipRRect(
                          borderRadius: AppRadii.matRadius,
                          child: SizedBox.square(
                            dimension: resolvedImageExtent,
                            child: image,
                          ),
                        ),
                      ),
                      SizedBox(height: imageToTitleGap),
                      Text(
                        title,
                        maxLines: titleMaxLines,
                        overflow: TextOverflow.ellipsis,
                        style: titleStyle ??
                            CollectibleTypography.catalogSeriesRowTitle(
                              textTheme,
                              scheme,
                            ),
                      ),
                      if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                        SizedBox(height: titleToMetaGap),
                        Text(
                          subtitle!,
                          maxLines: subtitleMaxLines,
                          overflow: TextOverflow.ellipsis,
                          style: subtitleStyle ??
                              CollectibleTypography.seriesIpLine(
                                textTheme,
                                scheme,
                              ),
                        ),
                      ],
                      const Spacer(),
                      if (footer != null) ...[
                        SizedBox(height: metaToFooterGap),
                        footer!,
                      ],
                    ],
                  ),
                ),
              ),
              IgnorePointer(
                child: AnimatedOpacity(
                  opacity: showPressedOverlay ? 1 : 0,
                  duration: const Duration(milliseconds: 100),
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.08),
                  ),
                ),
              ),
              if (overlayBuilder != null) overlayBuilder!(context),
            ],
          ),
        ),
      ),
    );
  }
}
