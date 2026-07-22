import 'package:blindbox_app/core/theme/app_radii.dart';
import 'package:blindbox_app/core/theme/app_spacing.dart';
import 'package:flutter/material.dart';

const String kCameraCaptureGuidance =
    'Keep the collectible centered and in focus.';

/// Shows the shared, camera-only guidance shown before launching the system UI.
Future<bool> showCameraCaptureGuidance(BuildContext context) async {
  final shouldOpenCamera = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: false,
    requestFocus: false,
    useSafeArea: true,
    isScrollControlled: false,
    showDragHandle: true,
    shape: AppRadii.sheetShape,
    builder: (sheetContext) => const _CameraCaptureGuidanceSheet(),
  );
  return shouldOpenCamera ?? false;
}

class _CameraCaptureGuidanceSheet extends StatelessWidget {
  const _CameraCaptureGuidanceSheet();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      key: const Key('camera-capture-guidance'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.sm,
        AppSpacing.xl,
        AppSpacing.xxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.center_focus_strong_rounded,
                size: 24,
                color: scheme.primary,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  kCameraCaptureGuidance,
                  style: textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurface,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          FilledButton.icon(
            key: const Key('open-system-camera'),
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.photo_camera_outlined),
            label: const Text('Open Camera'),
          ),
        ],
      ),
    );
  }
}
