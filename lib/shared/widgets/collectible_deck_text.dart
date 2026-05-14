import 'package:blindbox_app/core/theme/collectible_tokens.dart';
import 'package:flutter/material.dart';

/// Supportive / deck copy — lighter than default body for scanability.
class CollectibleDeckText extends StatelessWidget {
  const CollectibleDeckText(
    this.text, {
    super.key,
    this.textAlign,
    this.meta = false,
  });

  /// Smaller, quieter line (attribution, footnotes).
  const CollectibleDeckText.meta(
    this.text, {
    super.key,
    this.textAlign,
  }) : meta = true;

  final String text;
  final TextAlign? textAlign;
  final bool meta;

  @override
  Widget build(BuildContext context) {
    final tokens = CollectibleTokens.of(context);
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final style = meta ? tokens.supportiveMeta(textTheme, scheme) : tokens.supportiveBody(textTheme, scheme);
    return Text(text, textAlign: textAlign, style: style);
  }
}
