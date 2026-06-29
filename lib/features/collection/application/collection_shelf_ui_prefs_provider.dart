import 'dart:convert';

import 'package:blindbox_app/features/collection/presentation/collection_shelf_browse.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kCollectionShelfUiPrefsKey = 'collection_shelf_ui_prefs_v1';

@immutable
class CollectionShelfUiPrefs {
  const CollectionShelfUiPrefs({
    this.sort = CollectionShelfSort.recentlyAdded,
    this.inProgressSectionExpanded = true,
    this.completedSectionExpanded = false,
    this.collapsedIpSectionKeys = const {},
  });

  final CollectionShelfSort sort;
  final bool inProgressSectionExpanded;
  final bool completedSectionExpanded;
  final Set<String> collapsedIpSectionKeys;

  CollectionShelfUiPrefs copyWith({
    CollectionShelfSort? sort,
    bool? inProgressSectionExpanded,
    bool? completedSectionExpanded,
    Set<String>? collapsedIpSectionKeys,
  }) {
    return CollectionShelfUiPrefs(
      sort: sort ?? this.sort,
      inProgressSectionExpanded:
          inProgressSectionExpanded ?? this.inProgressSectionExpanded,
      completedSectionExpanded:
          completedSectionExpanded ?? this.completedSectionExpanded,
      collapsedIpSectionKeys:
          collapsedIpSectionKeys ?? this.collapsedIpSectionKeys,
    );
  }

  bool isIpSectionExpanded(String sectionKey) =>
      !collapsedIpSectionKeys.contains(sectionKey);
}

abstract final class CollectionShelfUiPrefsCodec {
  static CollectionShelfUiPrefs decode(String? raw) {
    if (raw == null || raw.isEmpty) return const CollectionShelfUiPrefs();
    try {
      final map = jsonDecode(raw);
      if (map is! Map<String, dynamic>) return const CollectionShelfUiPrefs();

      final sort = CollectionShelfSortLabels.tryParse(map['sort'] as String?) ??
          CollectionShelfSort.recentlyAdded;
      final inProgressExpanded = map['inProgressSectionExpanded'] != false;
      final completedExpanded = map['completedSectionExpanded'] == true;
      final collapsedRaw = map['collapsedIpSectionKeys'];
      final collapsed = collapsedRaw is List
          ? collapsedRaw.whereType<String>().toSet()
          : const <String>{};

      return CollectionShelfUiPrefs(
        sort: sort,
        inProgressSectionExpanded: inProgressExpanded,
        completedSectionExpanded: completedExpanded,
        collapsedIpSectionKeys: collapsed,
      );
    } catch (_) {
      return const CollectionShelfUiPrefs();
    }
  }

  static String encode(CollectionShelfUiPrefs prefs) {
    return jsonEncode({
      'sort': prefs.sort.name,
      'inProgressSectionExpanded': prefs.inProgressSectionExpanded,
      'completedSectionExpanded': prefs.completedSectionExpanded,
      'collapsedIpSectionKeys': prefs.collapsedIpSectionKeys.toList()..sort(),
    });
  }
}

abstract final class CollectionShelfUiPrefsStorage {
  static Future<CollectionShelfUiPrefs> load() async {
    final prefs = await SharedPreferences.getInstance();
    return CollectionShelfUiPrefsCodec.decode(
      prefs.getString(kCollectionShelfUiPrefsKey),
    );
  }

  static Future<void> save(CollectionShelfUiPrefs prefs) async {
    final shared = await SharedPreferences.getInstance();
    await shared.setString(
      kCollectionShelfUiPrefsKey,
      CollectionShelfUiPrefsCodec.encode(prefs),
    );
  }

  static Future<void> clear() async {
    final shared = await SharedPreferences.getInstance();
    await shared.remove(kCollectionShelfUiPrefsKey);
  }
}

final collectionShelfUiPrefsProvider =
    NotifierProvider<CollectionShelfUiPrefsNotifier, CollectionShelfUiPrefs>(
  CollectionShelfUiPrefsNotifier.new,
);

class CollectionShelfUiPrefsNotifier extends Notifier<CollectionShelfUiPrefs> {
  @override
  CollectionShelfUiPrefs build() {
    _loadFromStorage();
    return const CollectionShelfUiPrefs();
  }

  Future<void> _loadFromStorage() async {
    final loaded = await CollectionShelfUiPrefsStorage.load();
    if (loaded != state) {
      state = loaded;
    }
  }

  void setSort(CollectionShelfSort sort) {
    if (state.sort == sort) return;
    state = state.copyWith(sort: sort);
    _persist();
  }

  void toggleInProgressSection() {
    state = state.copyWith(
      inProgressSectionExpanded: !state.inProgressSectionExpanded,
    );
    _persist();
  }

  void toggleCompletedSection() {
    state = state.copyWith(
      completedSectionExpanded: !state.completedSectionExpanded,
    );
    _persist();
  }

  void toggleIpSection(String sectionKey) {
    final collapsed = Set<String>.from(state.collapsedIpSectionKeys);
    if (collapsed.contains(sectionKey)) {
      collapsed.remove(sectionKey);
    } else {
      collapsed.add(sectionKey);
    }
    state = state.copyWith(collapsedIpSectionKeys: collapsed);
    _persist();
  }

  void _persist() {
    CollectionShelfUiPrefsStorage.save(state);
  }
}
