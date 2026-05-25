import 'package:blindbox_app/features/market/taxonomy/taxonomy_models.dart';

/// Curated brand rows — expand by appending const entries only.
abstract final class BrandTaxonomyRegistry {
  static const List<BrandTaxonomy> all = [
    BrandTaxonomy(
      id: 'pop_mart',
      displayName: 'POP MART',
      aliases: ['POP MART', 'POPMART'],
    ),
    BrandTaxonomy(
      id: 'dreams_inc',
      displayName: 'Dreams Inc.',
      aliases: ['DREAMS INC', 'DREAMS'],
    ),
    BrandTaxonomy(
      id: 'rolife',
      displayName: 'Rolife',
      aliases: ['ROLIFE'],
    ),
    BrandTaxonomy(
      id: 'finding_unicorn',
      displayName: 'Finding Unicorn',
      aliases: ['FINDING UNICORN'],
    ),
    BrandTaxonomy(
      id: 'tntspace',
      displayName: 'TNT SPACE',
      aliases: ['TNT SPACE', 'TNTSPACE'],
    ),
    BrandTaxonomy(
      id: 'toptoy',
      displayName: 'TOPTOY',
      aliases: ['TOPTOY', 'TOP TOY'],
    ),
    BrandTaxonomy(
      id: 'dpl',
      displayName: 'DPL',
      aliases: ['DPL', 'CUREPLANETA'],
    ),
  ];
}
