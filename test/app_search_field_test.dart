import 'package:blindbox_app/core/theme/app_spacing.dart';
import 'package:blindbox_app/shared/widgets/app_search_field.dart';
import 'package:blindbox_app/shared/image/catalog_photo_acquisition.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

class _FakePhotoAcquirer implements CatalogPhotoAcquirer {
  _FakePhotoAcquirer({this.result, this.error});
  final CatalogPhotoSelection? result;
  final Object? error;
  CatalogPhotoSource? requested;

  @override
  Future<CatalogPhotoSelection?> acquire(CatalogPhotoSource source) async {
    requested = source;
    if (error != null) throw error!;
    return result;
  }
}

Future<void> _pumpPhotoField(
  WidgetTester tester, {
  CatalogPhotoAcquirer? acquirer,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: AppSearchField(
          photoAcquirer: acquirer ?? _FakePhotoAcquirer(),
          onImageSelected: (_) {},
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const Key('catalog-photo-action')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('AppSearchField uses M3 prefix constraints and text inset', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AppSearchField(hintText: 'Search catalog')),
      ),
    );

    final field = tester.widget<TextField>(find.byType(TextField));
    final decoration = field.decoration!;

    expect(decoration.prefixIconConstraints?.minWidth, 48);
    expect(
      decoration.contentPadding,
      const EdgeInsets.fromLTRB(12, 14, 12, 14),
    );
    expect(
      decoration.contentPadding?.resolve(TextDirection.ltr).left,
      AppSpacing.md,
    );
  });

  testWidgets('AppSearchField disabled state lowers chrome and input opacity', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppSearchField(hintText: 'Search collection', enabled: false),
        ),
      ),
    );

    final field = tester.widget<TextField>(find.byType(TextField));
    final decoration = field.decoration!;
    final prefixIcon = decoration.prefixIcon! as Icon;
    final fieldOpacity = tester.widget<Opacity>(
      find.ancestor(of: find.byType(TextField), matching: find.byType(Opacity)),
    );

    expect(field.enabled, isFalse);
    expect(field.readOnly, isTrue);
    expect(field.showCursor, isFalse);
    expect(fieldOpacity.opacity, closeTo(0.44, 0.01));
    expect(decoration.hintStyle?.color?.a, closeTo(0.34, 0.01));
    expect(prefixIcon.color?.a, closeTo(0.3, 0.01));
  });

  testWidgets(
    'photo action preserves search input and returns camera selection',
    (tester) async {
      final selection = CatalogPhotoSelection(
        file: XFile.fromData(
          Uint8List.fromList([1, 2, 3]),
          name: 'photo.jpg',
          mimeType: 'image/jpeg',
        ),
        source: CatalogPhotoSource.camera,
      );
      final acquirer = _FakePhotoAcquirer(result: selection);
      CatalogPhotoSelection? received;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppSearchField(
              hintText: 'Search catalog',
              photoAcquirer: acquirer,
              onImageSelected: (value) => received = value,
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'Hirono');
      final fieldPosition = tester.getTopLeft(find.byType(TextField));
      await tester.tap(find.byKey(const Key('catalog-photo-action')));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.byType(TextField)), fieldPosition);
      expect(find.text('Take Photo'), findsOneWidget);
      expect(find.text('Choose from Photos'), findsOneWidget);
      await tester.tap(find.text('Take Photo'));
      await tester.pumpAndSettle();
      expect(acquirer.requested, CatalogPhotoSource.camera);
      expect(received, same(selection));
      expect(find.text('Hirono'), findsOneWidget);
    },
  );

  testWidgets('gallery and cancellation are delegated safely', (tester) async {
    final acquirer = _FakePhotoAcquirer();
    var callbacks = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppSearchField(
            photoAcquirer: acquirer,
            onImageSelected: (_) => callbacks++,
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('catalog-photo-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(acquirer.requested, isNull);
    await tester.tap(find.byKey(const Key('catalog-photo-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose from Photos'));
    await tester.pumpAndSettle();
    expect(acquirer.requested, CatalogPhotoSource.gallery);
    expect(callbacks, 0); // Native picker cancellation returns null.
  });

  testWidgets('photo sheet dismissal does not restore search focus', (
    tester,
  ) async {
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppSearchField(
            focusNode: focusNode,
            photoAcquirer: _FakePhotoAcquirer(),
            onImageSelected: (_) {},
          ),
        ),
      ),
    );
    focusNode.requestFocus();
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);

    await tester.tap(find.byKey(const Key('catalog-photo-action')));
    await tester.pumpAndSettle();
    expect(focusNode.hasFocus, isFalse);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(focusNode.hasFocus, isFalse);
  });

  testWidgets(
    'permission denial is user-safe and compact layout does not overflow',
    (tester) async {
      final acquirer = _FakePhotoAcquirer(
        error: PlatformException(code: 'camera_access_denied'),
      );
      await tester.binding.setSurfaceSize(const Size(280, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppSearchField(
              suffixIcon: const Icon(Icons.close),
              photoAcquirer: acquirer,
              onImageSelected: (_) {},
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('catalog-photo-action')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Take Photo'));
      await tester.pumpAndSettle();
      expect(find.textContaining('access was denied'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('dragging the handle beyond threshold dismisses the sheet', (
    tester,
  ) async {
    await _pumpPhotoField(tester);
    await tester.drag(
      find.byKey(const Key('photo-source-drag-region')),
      const Offset(0, 180),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('photo-source-sheet')), findsNothing);
  });

  testWidgets('a short handle drag follows the finger then snaps back', (
    tester,
  ) async {
    await _pumpPhotoField(tester);
    final sheet = find.byKey(const Key('photo-source-sheet'));
    final restingPosition = tester.getTopLeft(sheet);
    final bottomSheet = find.ancestor(
      of: sheet,
      matching: find.byType(BottomSheet),
    );
    final restingAnimationValue = tester
        .widget<BottomSheet>(bottomSheet)
        .animationController!
        .value;
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('photo-source-drag-region'))),
    );
    await gesture.moveBy(const Offset(0, 20));
    await tester.pump();
    await gesture.moveBy(const Offset(0, 60));
    await tester.pump();
    expect(
      tester.widget<BottomSheet>(bottomSheet).animationController!.value,
      lessThan(restingAnimationValue),
    );
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('photo-source-sheet')), findsOneWidget);
    expect(tester.getTopLeft(sheet), restingPosition);
  });

  testWidgets('a fast downward fling dismisses below the distance threshold', (
    tester,
  ) async {
    await _pumpPhotoField(tester);
    await tester.fling(
      find.byKey(const Key('photo-source-drag-region')),
      const Offset(0, 60),
      3000,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('photo-source-sheet')), findsNothing);
  });
}
