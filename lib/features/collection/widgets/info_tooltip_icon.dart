import 'package:flutter/material.dart';

class InfoTooltipIcon extends StatefulWidget {
  const InfoTooltipIcon({
    super.key,
    required this.message,
    required this.color,
    this.size = 14,
  });

  final String message;
  final Color color;
  final double size;

  @override
  State<InfoTooltipIcon> createState() => _InfoTooltipIconState();
}

class _InfoTooltipIconState extends State<InfoTooltipIcon> {
  final _tooltipKey = GlobalKey<TooltipState>();

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      key: _tooltipKey,
      message: widget.message,
      triggerMode: TooltipTriggerMode.manual,
      enableTapToDismiss: true,
      child: Semantics(
        button: true,
        label: 'More information',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _tooltipKey.currentState?.ensureTooltipVisible(),
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: Icon(
              Icons.info_outline_rounded,
              size: widget.size,
              color: widget.color,
            ),
          ),
        ),
      ),
    );
  }
}
