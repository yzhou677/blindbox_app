import 'package:blindbox_app/features/market/debug/market_search_trace.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Search Market overlay session — taxonomy-free; query only.
@immutable
class MarketSearchBrowseState {
  const MarketSearchBrowseState({
    this.query = '',
    this.isCommitted = false,
  });

  final String query;
  final bool isCommitted;

  MarketSearchBrowseState copyWith({
    String? query,
    bool? isCommitted,
  }) {
    return MarketSearchBrowseState(
      query: query ?? this.query,
      isCommitted: isCommitted ?? this.isCommitted,
    );
  }
}

final marketSearchBrowseNotifierProvider =
    NotifierProvider<MarketSearchBrowseNotifier, MarketSearchBrowseState>(
  MarketSearchBrowseNotifier.new,
);

/// True while `/market/search` route is on screen.
final marketSearchOverlayOpenProvider =
    NotifierProvider<MarketSearchOverlayOpenNotifier, bool>(
  MarketSearchOverlayOpenNotifier.new,
);

class MarketSearchOverlayOpenNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setOpen(bool open) => state = open;
}

class MarketSearchBrowseNotifier extends Notifier<MarketSearchBrowseState> {
  @override
  MarketSearchBrowseState build() => const MarketSearchBrowseState();

  /// Clean slate when entering Search Market.
  void beginOverlay() {
    state = const MarketSearchBrowseState();
  }

  /// Debounced commit from the search field.
  void commitQuery(String value) {
    final empty = value.trim().isEmpty;
    MarketSearchTrace.event(
      'marketSearchBrowse.commitQuery committed=${!empty}',
      signature: value.trim().toLowerCase(),
    );
    state = state.copyWith(
      query: value,
      isCommitted: !empty,
    );
  }

  void clearSession() {
    state = const MarketSearchBrowseState();
  }
}
