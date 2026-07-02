import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/shared/widgets/app_search_field.dart';
import 'package:blindbox_app/shared/widgets/feed_search_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _ProbeHost extends StatefulWidget {
  const _ProbeHost({super.key});

  @override
  State<_ProbeHost> createState() => _ProbeHostState();
}

class _ProbeHostState extends State<_ProbeHost> {
  int buildCount = 0;
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    buildCount++;
    return MaterialApp(
      theme: AppTheme.light(),
      home: FeedSearchScreen(
        title: 'Search catalog',
        hintText: 'Search…',
        emptyPrompt: 'Empty prompt',
        controller: _controller,
        onChanged: (_) {},
        onClear: () => _controller.clear(),
        historySection: const Text('history-section'),
        results: const Text('results-section'),
      ),
    );
  }
}

void main() {
  testWidgets('clear suffix is driven by ValueListenableBuilder without parent rebuild', (
    tester,
  ) async {
    final hostKey = GlobalKey<_ProbeHostState>();
    await tester.pumpWidget(_ProbeHost(key: hostKey));
    await tester.pump();

    final initialBuilds = hostKey.currentState!.buildCount;
    expect(find.byTooltip('Clear'), findsNothing);

    await tester.enterText(
      find.descendant(
        of: find.byType(AppSearchField),
        matching: find.byType(TextField),
      ),
      'labubu',
    );
    await tester.pump();

    expect(
      hostKey.currentState!.buildCount,
      initialBuilds,
      reason: 'parent must not rebuild when only suffix chrome changes',
    );
    expect(find.byTooltip('Clear'), findsOneWidget);
    expect(find.text('Matches'), findsOneWidget);
    expect(find.text('results-section'), findsOneWidget);
    expect(find.text('history-section'), findsNothing);
  });

  testWidgets('whitespace-only query keeps history chrome without clear suffix', (
    tester,
  ) async {
    await tester.pumpWidget(const _ProbeHost());
    await tester.pump();

    await tester.enterText(
      find.descendant(
        of: find.byType(AppSearchField),
        matching: find.byType(TextField),
      ),
      '   ',
    );
    await tester.pump();

    expect(find.byTooltip('Clear'), findsNothing);
    expect(find.text('Matches'), findsNothing);
    expect(find.text('history-section'), findsOneWidget);
  });
}
