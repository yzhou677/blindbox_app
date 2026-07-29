import 'package:blindbox_app/features/collection/insights/debug/companion/collector_companion.dart';
import 'package:blindbox_app/features/collection/insights/debug/companion/collector_companion_assets.dart';
import 'package:blindbox_app/features/collection/insights/debug/companion/companion_reaction.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Debug-only playground to validate Companion motion / charm.
///
/// Open via `context.push(CollectorCompanionPlayground.routePath)` in debug,
/// or:
/// `flutter run --dart-define=COMPANION_PLAYGROUND=true`
class CollectorCompanionPlayground extends StatefulWidget {
  const CollectorCompanionPlayground({super.key});

  static const routePath = '/debug/collector-companion';

  /// True when launched with `--dart-define=COMPANION_PLAYGROUND=true`.
  static const launchViaDefine = bool.fromEnvironment(
    'COMPANION_PLAYGROUND',
    defaultValue: false,
  );

  @override
  State<CollectorCompanionPlayground> createState() =>
      _CollectorCompanionPlaygroundState();
}

class _CollectorCompanionPlaygroundState
    extends State<CollectorCompanionPlayground> {
  final _companionKey = GlobalKey<CollectorCompanionState>();

  CompanionReaction _selected = CompanionReaction.idle;
  CompanionReaction _displayed = CompanionReaction.idle;
  bool _loopReaction = false;
  bool _idleLife = true;

  double _motionSpeed = 1.0;
  double _floatAmount = 1.0;
  double _headRotation = 1.0;
  double _breathing = 1.0;
  double _sparkle = 1.0;
  double _durationScale = 1.0;

  @override
  Widget build(BuildContext context) {
    assert(kDebugMode, 'CollectorCompanionPlayground is debug-only');

    return Scaffold(
      backgroundColor: const Color(0xFF1E1F1C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A2B27),
        title: const Text('Companion Playground (debug)'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            const Text(
              'Internal motion lab — micro-polish pose. Not a product screen.',
              style: TextStyle(color: Color(0xFF9AA392), fontSize: 12),
            ),
            const SizedBox(height: 12),
            Container(
              height: 340,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF2F312C),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF3E413A)),
              ),
              child: CollectorCompanion(
                key: _companionKey,
                assets: CollectorCompanionAssets.completionist,
                size: 300,
                reaction: CompanionReaction.idle,
                motionSpeed: _motionSpeed,
                floatAmount: _floatAmount,
                headRotationAmount: _headRotation,
                breathingAmount: _breathing,
                sparkleIntensity: _sparkle,
                animationDurationScale: _durationScale,
                loopIdle: true,
                idleLife: _idleLife,
                onReactionCompleted: _onReactionCompleted,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'State: ${_displayed.name}',
              style: const TextStyle(
                color: Color(0xFFE6E8E1),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            const _SectionLabel('Reactions'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final reaction in CompanionReaction.values)
                  ChoiceChip(
                    label: Text(reaction.name),
                    selected: _selected == reaction,
                    onSelected: (_) => setState(() => _selected = reaction),
                    selectedColor: const Color(0xFF5B6B52),
                    labelStyle: TextStyle(
                      color: _selected == reaction
                          ? Colors.white
                          : const Color(0xFFD5D8CF),
                      fontSize: 12,
                    ),
                    backgroundColor: const Color(0xFF3A3C36),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  key: const Key('companion_playground_play'),
                  onPressed: _play,
                  child: const Text('Play'),
                ),
                OutlinedButton(
                  key: const Key('companion_playground_reset'),
                  onPressed: _reset,
                  child: const Text('Reset'),
                ),
                FilterChip(
                  label: const Text('Loop reaction'),
                  selected: _loopReaction,
                  onSelected: (v) => setState(() => _loopReaction = v),
                ),
                FilterChip(
                  label: const Text('Idle life (nod/sway)'),
                  selected: _idleLife,
                  onSelected: (v) => setState(() => _idleLife = v),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const _SectionLabel('Animation controls'),
            _SliderRow(
              label: 'Motion speed',
              value: _motionSpeed,
              min: 0.4,
              max: 2.0,
              onChanged: (v) => setState(() => _motionSpeed = v),
            ),
            _SliderRow(
              label: 'Float amount',
              value: _floatAmount,
              min: 0,
              max: 2,
              onChanged: (v) => setState(() => _floatAmount = v),
            ),
            _SliderRow(
              label: 'Head rotation',
              value: _headRotation,
              min: 0,
              max: 2,
              onChanged: (v) => setState(() => _headRotation = v),
            ),
            _SliderRow(
              label: 'Breathing amount',
              value: _breathing,
              min: 0,
              max: 2,
              onChanged: (v) => setState(() => _breathing = v),
            ),
            _SliderRow(
              label: 'Sparkle intensity',
              value: _sparkle,
              min: 0,
              max: 2,
              onChanged: (v) => setState(() => _sparkle = v),
            ),
            _SliderRow(
              label: 'Animation duration',
              value: _durationScale,
              min: 0.5,
              max: 2,
              onChanged: (v) => setState(() => _durationScale = v),
            ),
          ],
        ),
      ),
    );
  }

  void _play() {
    setState(() => _displayed = _selected);
    _companionKey.currentState?.playReaction(_selected);
  }

  void _reset() {
    setState(() {
      _selected = CompanionReaction.idle;
      _displayed = CompanionReaction.idle;
      _loopReaction = false;
    });
    _companionKey.currentState?.resetToIdle();
  }

  void _onReactionCompleted(CompanionReaction done) {
    if (!mounted) return;
    if (_loopReaction && _selected != CompanionReaction.idle) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_loopReaction) return;
        _companionKey.currentState?.playReaction(_selected);
        setState(() => _displayed = _selected);
      });
      return;
    }
    setState(() => _displayed = CompanionReaction.idle);
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFFB7BDAE),
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(color: Color(0xFFD5D8CF), fontSize: 12),
              ),
            ),
            Text(
              value.toStringAsFixed(2),
              style: const TextStyle(color: Color(0xFF9AA392), fontSize: 12),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
