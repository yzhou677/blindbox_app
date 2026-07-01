// Debug-mode pipeline audit entry point (dev tooling only).
//
//   flutter run --debug -t tools/profile/collection_pipeline_toggle_audit.dart -d <device>
//
// Confirms CollectionPipeline logs fire once on mount, not on dashboard toggle.

import 'dart:async';
import 'dart:ui';

import 'package:blindbox_app/core/theme/collectible_tokens.dart';
import 'package:blindbox_app/features/collection/application/collection_insights_dashboard_providers.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/widgets/collection_insights_dashboard_host.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  if (!kDebugMode) {
    debugPrint(
      'PIPELINE_AUDIT|skip|reason=not_debug_mode|'
      'CollectionPipeline logs are debug-only',
    );
  }
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ProviderScope(
      overrides: [
        collectionNotifierProvider.overrideWith(
          () => _FixedCollectionNotifier(
            CollectionSnapshot(
              shelfSeries: [
                ShelfSeries(
                  id: 'audit-series',
                  name: 'Audit Series',
                  brand: 'POP MART',
                  ipName: 'The Monsters',
                  figures: const [
                    ShelfFigure(
                      id: 'fig_audit_0',
                      seriesId: 'audit-series',
                      name: 'Audit Figure',
                      rarity: 'Regular',
                      isSecret: false,
                    ),
                  ],
                  shelfAccent: Color(0xFFE4F2EA),
                ),
              ],
              figureStates: const {},
            ),
          ),
        ),
      ],
      child: const _PipelineAuditApp(),
    ),
  );
}

class _PipelineAuditApp extends StatefulWidget {
  const _PipelineAuditApp();

  @override
  State<_PipelineAuditApp> createState() => _PipelineAuditAppState();
}

class _PipelineAuditAppState extends State<_PipelineAuditApp> {
  static const _toggleKey = Key('collection_insights_dashboard_toggle');
  int _shelfBuilds = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_runAudit());
    });
  }

  BuildContext? _findContext(Key key) {
    BuildContext? found;
    void visitor(Element element) {
      if (element.widget.key == key) {
        found = element;
        return;
      }
      element.visitChildren(visitor);
    }
    WidgetsBinding.instance.rootElement?.visitChildren(visitor);
    return found;
  }

  Future<void> _runAudit() async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final before = _shelfBuilds;
    for (var i = 0; i < 5; i++) {
      await _tapToggle();
      await Future<void>.delayed(const Duration(milliseconds: 320));
    }
    final delta = _shelfBuilds - before;
    debugPrint(
      'PIPELINE_AUDIT|shelfRebuildsDuring5Toggles=$delta|'
      'expect=0|note=watch_logcat_for_single_CollectionPipeline_mount_only',
    );
  }

  Future<void> _tapToggle() async {
    final context = _findContext(_toggleKey);
    if (context == null) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final center = box.localToGlobal(box.size.center(Offset.zero));
    final binding = WidgetsBinding.instance;
    binding.handlePointerEvent(
      PointerDownEvent(position: center, pointer: 1),
    );
    await Future<void>.delayed(const Duration(milliseconds: 16));
    binding.handlePointerEvent(
      PointerUpEvent(position: center, pointer: 1),
    );
    await binding.endOfFrame;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        extensions: [CollectibleTokens.forBrightness(Brightness.light)],
      ),
      home: Scaffold(
        body: Column(
          children: [
            const CollectionInsightsDashboardHost(),
            Expanded(
              child: _ShelfStub(onBuild: () => _shelfBuilds++),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShelfStub extends StatelessWidget {
  const _ShelfStub({required this.onBuild});

  final VoidCallback onBuild;

  @override
  Widget build(BuildContext context) {
    onBuild();
    return const Center(child: Text('shelf-feed-stub'));
  }
}

class _FixedCollectionNotifier extends CollectionNotifier {
  _FixedCollectionNotifier(this._fixed);
  final CollectionSnapshot _fixed;

  @override
  CollectionSnapshot build() => _fixed;
}
