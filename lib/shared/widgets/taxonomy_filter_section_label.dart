import 'package:blindbox_app/core/theme/app_typography.dart';
import 'package:flutter/material.dart';

/// Quiet one-word heading above taxonomy filter chip rails (Brand / IP).
class TaxonomyFilterSectionLabel extends StatelessWidget {
  const TaxonomyFilterSectionLabel({
    super.key,
    required this.text,
    this.horizontalPadding = 20,
  });

  final String text;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Semantics(
        header: true,
        child: Text(text, style: AppTypography.sectionLabel(textTheme, scheme)),
      ),
    );
  }
}
