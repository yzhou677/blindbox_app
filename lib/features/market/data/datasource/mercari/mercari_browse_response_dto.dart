import 'package:blindbox_app/features/market/data/datasource/mercari/mercari_listing_dto.dart';
import 'package:flutter/foundation.dart';

@immutable
class MercariBrowseResponseDto {
  const MercariBrowseResponseDto({
    required this.items,
    this.nextCursor,
    this.hasMore = false,
  });

  final List<MercariListingDto> items;
  final String? nextCursor;
  final bool hasMore;

  factory MercariBrowseResponseDto.fromJson(Map<String, dynamic> json) {
    final raw = json['items'] as List<dynamic>? ?? const [];
    final items = <MercariListingDto>[];
    for (final e in raw) {
      if (e is! Map<String, dynamic>) continue;
      final dto = MercariListingDto.tryParse(e);
      if (dto != null) items.add(dto);
    }

    final cursor = _readCursor(json);
    final explicitMore = json['hasMore'] as bool?;
    final hasMore = explicitMore ?? (cursor != null && cursor.isNotEmpty);

    return MercariBrowseResponseDto(
      items: items,
      nextCursor: cursor,
      hasMore: hasMore,
    );
  }

  static String? _readCursor(Map<String, dynamic> json) {
    final direct = json['nextCursor'] as String? ?? json['cursor'] as String?;
    if (direct != null && direct.trim().isNotEmpty) return direct.trim();
    final page = json['pagination'];
    if (page is Map<String, dynamic>) {
      final nested =
          page['nextCursor'] as String? ?? page['cursor'] as String?;
      if (nested != null && nested.trim().isNotEmpty) return nested.trim();
    }
    return null;
  }
}
