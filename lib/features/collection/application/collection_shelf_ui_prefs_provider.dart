import 'dart:convert';

import 'package:blindbox_app/features/collection/presentation/collection_shelf_browse.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_card_content.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_layout.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kCollectionShelfUiPrefsKey = 'collection_shelf_ui_prefs_v1';

@immutable
class CollectionShelfUiPrefs {
  const CollectionShelfUiPrefs({
    this.sort = CollectionShelfSort.recentlyAdded,
    this.layout = CollectionShelfLayout.grid,
    this.cardContent = CollectionShelfCardContentPrefs.empty,
    this.inProgressSectionExpanded = true,
    this.completedSectionExpanded = false,
    this.collapsedIpSectionKeys = const {},
  });

  final CollectionShelfSort sort;

  /// Visual arrangement — defaults to [CollectionShelfLayout.grid] for existing users.
  final CollectionShelfLayout layout;

  /// Shared optional Series Card metadata for **all** layouts.
  final CollectionShelfCardContentPrefs cardContent;

  final bool inProgressSectionExpanded;
  final bool completedSectionExpanded;
  final Set<String> collapsedIpSectionKeys;

  CollectionShelfCardContentSelection get cardContentSelection =>
      cardContent.selection;

  CollectionShelfUiPrefs copyWith({
    CollectionShelfSort? sort,
    CollectionShelfLayout? layout,
    CollectionShelfCardContentPrefs? cardContent,
    bool? inProgressSectionExpanded,
    bool? completedSectionExpanded,
    Set<String>? collapsedIpSectionKeys,
  }) {
    return CollectionShelfUiPrefs(
      sort: sort ?? this.sort,
      layout: layout ?? this.layout,
      cardContent: cardContent ?? this.cardContent,
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

  @override
  bool operator ==(Object other) {
    return other is CollectionShelfUiPrefs &&
        other.sort == sort &&
        other.layout == layout &&
        other.cardContent == cardContent &&
        other.inProgressSectionExpanded == inProgressSectionExpanded &&
        other.completedSectionExpanded == completedSectionExpanded &&
        setEquals(other.collapsedIpSectionKeys, collapsedIpSectionKeys);
  }

  @override
  int get hashCode => Object.hash(
    sort,
    layout,
    cardContent,
    inProgressSectionExpanded,
    completedSectionExpanded,
    Object.hashAllUnordered(collapsedIpSectionKeys),
  );
}

abstract final class CollectionShelfUiPrefsCodec {
  static CollectionShelfUiPrefs decode(String? raw) {
    if (raw == null || raw.isEmpty) return const CollectionShelfUiPrefs();
    try {
      final map = jsonDecode(raw);
      if (map is! Map<String, dynamic>) return const CollectionShelfUiPrefs();

      final sort =
          CollectionShelfSortLabels.tryParse(map['sort'] as String?) ??
          CollectionShelfSort.recentlyAdded;
      final layout =
          CollectionShelfLayoutLabels.tryParse(map['layout'] as String?) ??
          CollectionShelfLayout.grid;
      final inProgressExpanded = map['inProgressSectionExpanded'] != false;
      final completedExpanded = map['completedSectionExpanded'] == true;
      final collapsedRaw = map['collapsedIpSectionKeys'];
      final collapsed = collapsedRaw is List
          ? collapsedRaw.whereType<String>().toSet()
          : const <String>{};
      // Prefer the stored layout's legacy entry when normalizing old maps.
      final cardContent = CollectionShelfCardContentPrefs.decode(
        map['cardContent'],
        preferredLayout: layout,
      );

      return CollectionShelfUiPrefs(
        sort: sort,
        layout: layout,
        cardContent: cardContent,
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
      'layout': prefs.layout.name,
      'cardContent': prefs.cardContent.toJson(),
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
    // After await, [state] is initialized. Skip disk hydration if the
    // collector already mutated prefs away from the build() default.
    if (state != const CollectionShelfUiPrefs()) return;
    if (loaded != state) {
      state = loaded;
    }
  }

  void setSort(CollectionShelfSort sort) {
    if (state.sort == sort) return;
    state = state.copyWith(sort: sort);
    _persist();
  }

  void setLayout(CollectionShelfLayout layout) {
    if (state.layout == layout) return;
    // Layout-only write — Card Content is intentionally unchanged.
    state = state.copyWith(layout: layout);
    _persist();
  }

  void setCardContent(CollectionShelfCardContentSelection selection) {
    final next = CollectionShelfCardContentPrefs(selection);
    if (next == state.cardContent) return;
    state = state.copyWith(cardContent: next);
    _persist();
  }

  void toggleCardContentField(
    CollectionShelfCardContentField field, {
    required Set<CollectionShelfCardContentField> available,
  }) {
    final current = state.cardContentSelection;
    final toggled = current.toggle(field, available: available);
    final sanitized = toggled.sanitizePreservingUnavailable(available);
    if (sanitized == current) return;
    setCardContent(sanitized);
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
