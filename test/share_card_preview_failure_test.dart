import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:blindbox_app/features/sharing/application/share_card_file_store.dart';
import 'package:blindbox_app/features/sharing/application/share_card_renderer.dart';
import 'package:blindbox_app/features/sharing/presentation/share_card_preview.dart';
import 'package:blindbox_app/shared/widgets/shelfy_progress_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FailingRenderer extends ShareCardRenderer {
  const _FailingRenderer();

  @override
  Future<Uint8List> capturePng(
    GlobalKey key, {
    double pixelRatio = 3,
  }) async {
    throw StateError('capture failed');
  }
}

class _NoopFileStore extends ShareCardFileStore {
  const _NoopFileStore();

  @override
  Future<void> cleanupOldTemporaryPngs({
    Duration maxAge = const Duration(days: 2),
  }) async {}

  @override
  Future<File> writeTemporaryPng({
    required Uint8List bytes,
    required String basename,
  }) async {
    throw StateError('should not write');
  }
}

void main() {
  testWidgets('share card prepare failure shows Couldn\'t prepare SnackBar', (
    tester,
  ) async {
    late BuildContext hostContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              hostContext = context;
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    );

    unawaited(
      showShareCardPreview(
        context: hostContext,
        card: const SizedBox(width: 40, height: 40),
        basename: 'fail',
        loadingLabel: 'Preparing card…',
        previewTitle: 'Preview',
        renderer: const _FailingRenderer(),
        fileStore: const _NoopFileStore(),
      ),
    );

    await tester.pump();
    expect(find.byType(ShelfyProgressDialogContent), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    expect(find.byType(SnackBar), findsOneWidget);
    expect(
      find.text("Couldn't prepare this Shelfy card."),
      findsOneWidget,
    );
  });
}
