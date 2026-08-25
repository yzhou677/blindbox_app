import 'package:flutter/material.dart';

/// Rectangular edge alpha feather — fades each edge independently; corners blend.
///
/// Used on immersive gallery foregrounds so the figure dissolves into the blurred
/// backdrop rather than ending at a hard rectangle.
class CatalogImmersiveEdgeFeather extends StatelessWidget {
  const CatalogImmersiveEdgeFeather({
    super.key,
    required this.child,
    this.featherFraction = 0.11,
  });

  final Widget child;

  /// Fraction of each axis used for the fade band (8–14% per product spec).
  final double featherFraction;

  static const List<Color> _maskStops = [
    Color(0x00000000),
    Color(0xFF000000),
    Color(0xFF000000),
    Color(0x00000000),
  ];

  @override
  Widget build(BuildContext context) {
    final band = featherFraction.clamp(0.08, 0.14);
    final stops = [0.0, band, 1.0 - band, 1.0];

    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: _maskStops,
        stops: stops,
      ).createShader(bounds),
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (bounds) => LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: _maskStops,
          stops: stops,
        ).createShader(bounds),
        child: child,
      ),
    );
  }
}
