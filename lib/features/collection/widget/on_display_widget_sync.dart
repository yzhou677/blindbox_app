import 'dart:async';
import 'dart:io';

import 'package:blindbox_app/core/media/device_local_ref.dart';
import 'package:blindbox_app/core/router/app_router.dart';
import 'package:blindbox_app/features/catalog/catalog_image_resolver.dart';
import 'package:blindbox_app/features/catalog/data/catalog_image_disk_cache.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/domain/series_completion_resolution.dart';
import 'package:blindbox_app/features/collection/widget/on_display_widget_payload.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

const _channel = MethodChannel('app.shelfy.collector/on_display_widget');

@immutable
sealed class OnDisplayWidgetNavigationTarget {
  const OnDisplayWidgetNavigationTarget();
}

class OnDisplayWidgetSeriesTarget extends OnDisplayWidgetNavigationTarget {
  const OnDisplayWidgetSeriesTarget(this.seriesId);

  final String seriesId;
}

class OnDisplayWidgetAddTarget extends OnDisplayWidgetNavigationTarget {
  const OnDisplayWidgetAddTarget();
}

final onDisplayWidgetNavigationProvider =
    StateProvider<OnDisplayWidgetNavigationTarget?>((ref) => null);

/// Active Shelf rows are the widget candidates. Series wishlist entries are
/// intentionally stored separately and never enter this list.
@visibleForTesting
List<ShelfSeries> eligibleOnDisplaySeries(CollectionSnapshot snapshot) =>
    [...snapshot.shelfSeries]..sort((a, b) => a.id.compareTo(b.id));

class OnDisplayWidgetSyncHost extends ConsumerStatefulWidget {
  const OnDisplayWidgetSyncHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<OnDisplayWidgetSyncHost> createState() =>
      _OnDisplayWidgetSyncHostState();
}

class _OnDisplayWidgetSyncHostState
    extends ConsumerState<OnDisplayWidgetSyncHost>
    with WidgetsBindingObserver {
  ProviderSubscription<CollectionSnapshot>? _subscription;
  Future<void> _pendingSync = Future<void>.value();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _channel.setMethodCallHandler(_handleNativeCall);
    _subscription = ref.listenManual(
      collectionNotifierProvider,
      (_, next) => _queueSync(next),
      fireImmediately: true,
    );
    unawaited(_readInitialNavigation());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    debugPrint('[OnDisplayWidget] app resumed; queueing widget export');
    _queueSync(ref.read(collectionNotifierProvider));
  }

  void _queueSync(CollectionSnapshot snapshot) {
    _pendingSync = _pendingSync
        .catchError((Object _) {})
        .then((_) => _syncSnapshot(snapshot));
  }

  Future<void> _readInitialNavigation() async {
    try {
      final target = await _channel.invokeMethod<String>('initialNavigation');
      if (target != null) _dispatchNavigation(target);
    } on MissingPluginException {
      // Non-Android platforms do not install the widget channel.
    } on PlatformException catch (error) {
      debugPrint('On Display initial navigation skipped: $error');
    }
  }

  Future<void> _handleNativeCall(MethodCall call) async {
    if (call.method != 'navigate') return;
    final target = call.arguments as String?;
    if (target != null) _dispatchNavigation(target);
  }

  void _dispatchNavigation(String rawTarget) {
    final target = rawTarget.trim();
    if (target == 'add') {
      appRouter.go('/collection');
      ref.read(onDisplayWidgetNavigationProvider.notifier).state =
          const OnDisplayWidgetAddTarget();
      return;
    }
    const prefix = 'series:';
    if (!target.startsWith(prefix)) return;
    final seriesId = target.substring(prefix.length).trim();
    if (seriesId.isEmpty) return;
    appRouter.go('/collection');
    ref.read(onDisplayWidgetNavigationProvider.notifier).state =
        OnDisplayWidgetSeriesTarget(seriesId);
  }

  Future<void> _syncSnapshot(CollectionSnapshot snapshot) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    debugPrint(
      '[OnDisplayWidget] total shelf series=${snapshot.shelfSeries.length}',
    );
    final eligible = eligibleOnDisplaySeries(snapshot);
    for (final series in snapshot.shelfSeries) {
      final progress = progressForSeries(series, snapshot.figureStates);
      debugPrint(
        '[OnDisplayWidget] eligibility seriesId=${series.id} '
        'seriesName=${series.name} owned=${progress.owned} '
        'wishlistOnly=false eligible=true reason=active-shelf-series',
      );
    }
    for (final series in snapshot.seriesWishlist) {
      debugPrint(
        '[OnDisplayWidget] eligibility seriesId=${series.catalogSeriesId} '
        'seriesName=${series.name} owned=0 wishlistOnly=true '
        'eligible=false reason=series-wishlist-only',
      );
    }
    debugPrint('[OnDisplayWidget] total eligible series=${eligible.length}');

    final payloads = <OnDisplayWidgetPayload>[];
    for (final series in eligible) {
      final progress = progressForSeries(series, snapshot.figureStates);
      final resolution = resolveSeriesCompletion(series, snapshot.figureStates);
      final payload = OnDisplayWidgetPayload(
        seriesId: series.id,
        seriesName: series.name,
        ipName: series.ipName,
        brand: series.brand,
        localCoverPath: await _localCoverPath(series),
        ownedFigureCount: progress.owned,
        regularOwned: resolution.regularOwnedCount,
        regularTotal: resolution.regularSlotCount,
        isComplete: resolution.isCompleted,
        isMasterComplete: resolution.isMasterComplete,
      );
      payloads.add(payload);
      debugPrint(
        '[OnDisplayWidget] candidate seriesId=${payload.seriesId} '
        'seriesName=${payload.seriesName} '
        'ownedFigureCount=${payload.ownedFigureCount} '
        'localCoverPath=${payload.localCoverPath}',
      );
    }

    debugPrint('[OnDisplayWidget] exported payload count=${payloads.length}');

    try {
      await _channel.invokeMethod<void>('sync', <String, Object>{
        'payloads': OnDisplayWidgetPayload.encodeList(payloads),
      });
    } on MissingPluginException {
      // Expected on non-Android test hosts.
    } on PlatformException catch (error) {
      debugPrint('On Display widget sync skipped: $error');
    }
  }

  Future<String> _localCoverPath(ShelfSeries series) async {
    final custom = series.customCoverImageUri?.trim();
    if (custom != null && custom.isNotEmpty) {
      final path = DeviceLocalImageRef.normalizeToFilePath(custom);
      if (await File(path).exists()) return path;
    }

    final imageKey = series.imageKey?.trim();
    if (imageKey == null || imageKey.isEmpty) return '';

    final asset = await CatalogImageResolver.resolveSeriesAsset(imageKey);
    if (asset != null) {
      try {
        final data = await rootBundle.load(asset);
        final root = await getApplicationSupportDirectory();
        final directory = Directory('${root.path}/on_display_widget');
        await directory.create(recursive: true);
        final safeId = series.id.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
        final file = File('${directory.path}/$safeId.img');
        await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
        return file.path;
      } on Object {
        return '';
      }
    }

    return await CatalogImageDiskCache.lookupLocalPath(
          kind: CatalogImageKind.series,
          imageKey: imageKey,
        ) ??
        '';
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.close();
    _channel.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
