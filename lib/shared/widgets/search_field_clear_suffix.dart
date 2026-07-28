import 'package:blindbox_app/core/theme/shelfy_symbols.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Clear affordance that rebuilds only when the field crosses empty ↔ non-empty.
///
/// Listening to every [TextEditingValue] change (e.g. bare [ValueListenableBuilder]
/// on the controller) rebuilds suffix chrome on each keystroke and can hitch
/// [TextField] input. This widget ignores intermediate characters while already
/// non-empty (or already empty).
class SearchFieldClearSuffix extends StatefulWidget {
  const SearchFieldClearSuffix({
    super.key,
    required this.controller,
    required this.onClear,
    this.iconColor,
  });

  final TextEditingController controller;
  final VoidCallback onClear;
  final Color? iconColor;

  /// Test-only: increments on every controller notification (including ignored).
  @visibleForTesting
  static int debugListenerFireCount = 0;

  /// Test-only: increments only when emptiness visibility toggles a rebuild.
  @visibleForTesting
  static int debugVisibilityRebuildCount = 0;

  @override
  State<SearchFieldClearSuffix> createState() => _SearchFieldClearSuffixState();
}

class _SearchFieldClearSuffixState extends State<SearchFieldClearSuffix> {
  late bool _visible;

  static bool _hasText(TextEditingController controller) =>
      controller.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _visible = _hasText(widget.controller);
    widget.controller.addListener(_onControllerTick);
  }

  @override
  void didUpdateWidget(covariant SearchFieldClearSuffix oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerTick);
      widget.controller.addListener(_onControllerTick);
      final next = _hasText(widget.controller);
      if (next != _visible) {
        _visible = next;
      }
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerTick);
    super.dispose();
  }

  void _onControllerTick() {
    assert(() {
      SearchFieldClearSuffix.debugListenerFireCount++;
      return true;
    }());
    final next = _hasText(widget.controller);
    if (next == _visible) return;
    assert(() {
      SearchFieldClearSuffix.debugVisibilityRebuildCount++;
      return true;
    }());
    setState(() => _visible = next);
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: 'Clear',
      icon: Icon(
        Symbols.close_rounded,
        size: AppIconSizes.clear,
        color:
            widget.iconColor ?? scheme.onSurfaceVariant.withValues(alpha: 0.7),
      ),
      onPressed: widget.onClear,
    );
  }
}
