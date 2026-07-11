import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_archetype.dart';
import 'package:blindbox_app/features/collection/insights/presentation/collector_type_mascot_assets.dart';
import 'package:blindbox_app/features/collection/insights/widgets/collector_type_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('avatar clips oval without border decoration', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: Center(
            child: CollectorTypeAvatar(
              key: Key('collector_type_mascot_dreamer'),
              assetPath: 'assets/insights/collector_types/dreamer.png',
              size: 96,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(ClipOval), findsOneWidget);
    expect(find.byType(Transform), findsWidgets);
    expect(find.byType(Image), findsOneWidget);

    final decorated = tester.widgetList<DecoratedBox>(find.byType(DecoratedBox));
    for (final box in decorated) {
      final border = box.decoration is BoxDecoration
          ? (box.decoration as BoxDecoration).border
          : null;
      expect(border, isNull);
    }
  });

  testWidgets('tryBuild returns an avatar for every collector type', (
    tester,
  ) async {
    for (final id in CollectorTypeArchetypeId.values) {
      expect(
        CollectorTypeAvatar.tryBuild(id: id, size: 48),
        isNotNull,
        reason: 'missing mascot for $id',
      );
      expect(
        CollectorTypeMascotAssets.assetPathFor(id),
        isNotNull,
      );
    }
  });
}
