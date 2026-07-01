// Profile-mode audit entry point (dev tooling only).
//
//   flutter run --profile -t tools/profile/collection_dashboard_profile_audit.dart -d <device>
//
// Automated expand/collapse cycles + frame timing + shelf rebuild counter.

import 'dart:async';
import 'dart:ui';

import 'package:blindbox_app/core/theme/collectible_motion.dart';
import 'package:blindbox_app/core/theme/collectible_tokens.dart';
import 'package:blindbox_app/features/collection/widgets/collection_insights_dashboard.dart';
import 'package:blindbox_app/features/collection/widgets/collection_summary_section.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

void main() {
  if (!kProfileMode) {
    debugPrint(
      'PROFILE_AUDIT|skip|reason=not_profile_mode|'
      'use: flutter run --profile -t tools/profile/collection_dashboard_profile_audit.dart',
    );
  }
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _ProfileAuditApp());
}

class _ProfileAuditApp extends StatefulWidget {
  const _ProfileAuditApp();

  @override
  State<_ProfileAuditApp> createState() => _ProfileAuditAppState();
}

class _ProfileAuditAppState extends State<_ProfileAuditApp> {
  static const _stats = CollectionAggregateStats(
    inCollection: 48,
    wantListCount: 3,
    completedSeriesCount: 7,
    masterCompleteSeriesCount: 5,
  );

  static const _toggleKey = Key('collection_insights_dashboard_toggle');
  static const _cycleCount = 4;

  final _frameSpans = <Duration>[];
  int _shelfBuilds = 0;
  var _cyclesDone = 0;
  var _reported = false;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_runCycles()));
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    super.dispose();
  }

  void _onTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      _frameSpans.add(Duration(microseconds: timing.totalSpan.inMicroseconds));
    }
  }

  Future<void> _runCycles() async {
    final transition = CollectibleMotion.insightsDashboardTransition;
    for (var i = 0; i < _cycleCount; i++) {
      if (!mounted) return;
      await _tapToggle();
      _cyclesDone++;
      // Let the unified transition complete plus a short settle.
      await Future<void>.delayed(transition + const Duration(milliseconds: 80));
    }
    if (!mounted || _reported) return;
    _reported = true;
    _printReport();
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

  void _printReport() {
    const budgetUs = 16667;
    var underBudget = 0;
    var maxUs = 0;
    var totalUs = 0;
    for (final span in _frameSpans) {
      final us = span.inMicroseconds;
      totalUs += us;
      if (us > maxUs) maxUs = us;
      if (us <= budgetUs) underBudget++;
    }
    final count = _frameSpans.length;
    final avgMs = count == 0 ? 0.0 : totalUs / count / 1000;
    final pct60 = count == 0 ? 0.0 : (underBudget * 100.0 / count);
    final stable60 = pct60 >= 95.0 && maxUs <= budgetUs * 2;

    debugPrint(
      'PROFILE_AUDIT|mode=${kProfileMode ? 'profile' : 'other'}'
      '|frames=$count'
      '|avgMs=${avgMs.toStringAsFixed(2)}'
      '|maxMs=${(maxUs / 1000).toStringAsFixed(2)}'
      '|under16p7ms=${pct60.toStringAsFixed(1)}%'
      '|stable60=$stable60'
      '|shelfBuilds=$_shelfBuilds'
      '|toggleCycles=$_cyclesDone',
    );
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
            CollectionInsightsDashboard(
              stats: _stats,
              shelfMoodLine: 'Your collection is quietly taking shape.',
              memoryWhisper: 'A gentle milestone on the shelf.',
              collectorTypeName: 'Curator',
              onInsightsTap: () {},
            ),
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
