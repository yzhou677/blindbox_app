import 'package:blindbox_app/features/market/data/datasource/mercari/mercari_listing_dto.dart';
import 'package:flutter/foundation.dart';

@immutable
class MercariBrowseResponseDto {
  const MercariBrowseResponseDto({required this.items});

  final List<MercariListingDto> items;

  factory MercariBrowseResponseDto.fromJson(Map<String, dynamic> json) {
    final raw = json['items'] as List<dynamic>? ?? const [];
    return MercariBrowseResponseDto(
      items: [
        for (final e in raw)
          if (e is Map<String, dynamic>)
            MercariListingDto.fromJson(e),
      ],
    );
  }
}
