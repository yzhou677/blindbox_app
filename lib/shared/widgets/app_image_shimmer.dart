import 'package:flutter/material.dart';

/// Soft pulsing placeholder while catalog art resolves or downloads.
class AppImageShimmer extends StatefulWidget {
  const AppImageShimmer({
    super.key,
    this.borderRadius = BorderRadius.zero,
  });

  final BorderRadius borderRadius;

  @override
  State<AppImageShimmer> createState() => _AppImageShimmerState();
}

class _AppImageShimmerState extends State<AppImageShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = scheme.surfaceContainerHighest.withValues(alpha: 0.38);
    final highlight = scheme.surfaceContainerLow.withValues(alpha: 0.55);

    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) {
          final t = Curves.easeInOut.transform(_pulse.value);
          return DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(-1 + t * 2, 0),
                end: Alignment(0.2 + t * 2, 0),
                colors: [base, highlight, base],
              ),
            ),
            child: child,
          );
        },
        child: const SizedBox.expand(),
      ),
    );
  }
}
