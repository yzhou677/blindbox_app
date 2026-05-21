import 'package:blindbox_app/features/market/taxonomy/taxonomy_models.dart';

/// Curated IP rows — expand by appending const entries only.
abstract final class IpTaxonomyRegistry {
  static const List<IpTaxonomy> all = [
    // POP MART
    IpTaxonomy(
      id: 'the_monsters',
      displayName: 'THE MONSTERS',
      brandId: 'pop_mart',
      aliases: ['LABUBU', 'THE MONSTERS', '拉布布'],
    ),
    IpTaxonomy(
      id: 'hirono',
      displayName: 'Hirono',
      brandId: 'pop_mart',
      aliases: ['HIRONO'],
    ),
    IpTaxonomy(
      id: 'skullpanda',
      displayName: 'Skullpanda',
      brandId: 'pop_mart',
      aliases: ['SKULLPANDA'],
    ),
    IpTaxonomy(
      id: 'crybaby',
      displayName: 'Crybaby',
      brandId: 'pop_mart',
      aliases: ['CRYBABY'],
    ),
    IpTaxonomy(
      id: 'dimoo',
      displayName: 'Dimoo',
      brandId: 'pop_mart',
      aliases: ['DIMOO'],
    ),
    IpTaxonomy(
      id: 'molly',
      displayName: 'Molly',
      brandId: 'pop_mart',
      aliases: ['MOLLY'],
    ),
    IpTaxonomy(
      id: 'peach_riot',
      displayName: 'Peach Riot',
      brandId: 'pop_mart',
      aliases: ['PEACH RIOT'],
    ),
    IpTaxonomy(
      id: 'nyota',
      displayName: 'Nyota',
      brandId: 'pop_mart',
      aliases: ['NYOTA'],
    ),
    IpTaxonomy(
      id: 'pucky',
      displayName: 'Pucky',
      brandId: 'pop_mart',
      aliases: ['PUCKY'],
    ),
    IpTaxonomy(
      id: 'hacipupu',
      displayName: 'Hacipupu',
      brandId: 'pop_mart',
      aliases: ['HACIPUPU'],
    ),
    IpTaxonomy(
      id: 'sweet_bean',
      displayName: 'Sweet Bean',
      brandId: 'pop_mart',
      aliases: ['SWEET BEAN'],
    ),
    IpTaxonomy(
      id: 'azura',
      displayName: 'Azura',
      brandId: 'pop_mart',
      aliases: ['AZURA'],
    ),
    IpTaxonomy(
      id: 'duckoo',
      displayName: 'Duckoo',
      brandId: 'pop_mart',
      aliases: ['DUCKOO'],
    ),
    IpTaxonomy(
      id: 'zsiga',
      displayName: 'Zsiga',
      brandId: 'pop_mart',
      aliases: ['ZSIGA'],
    ),
    // Dreams Inc.
    IpTaxonomy(
      id: 'sonny_angel',
      displayName: 'Sonny Angel',
      brandId: 'dreams_inc',
      aliases: ['SONNY ANGEL', 'SONNYANGEL'],
    ),
    IpTaxonomy(
      id: 'smiski',
      displayName: 'Smiski',
      brandId: 'dreams_inc',
      aliases: ['SMISKI'],
    ),
    // Rolife
    IpTaxonomy(
      id: 'nanci',
      displayName: 'Nanci',
      brandId: 'rolife',
      aliases: ['NANCI'],
    ),
    // Finding Unicorn
    IpTaxonomy(
      id: 'zzoton',
      displayName: 'Zzoton',
      brandId: 'finding_unicorn',
      aliases: ['ZZOTON'],
    ),
    IpTaxonomy(
      id: 'farmer_bob',
      displayName: 'Farmer Bob',
      brandId: 'finding_unicorn',
      aliases: ['FARMER BOB'],
    ),
    IpTaxonomy(
      id: 'rico',
      displayName: 'Rico',
      brandId: 'finding_unicorn',
      aliases: ['RICO'],
    ),
    IpTaxonomy(
      id: 'molinta',
      displayName: 'Molinta',
      brandId: 'finding_unicorn',
      aliases: ['MOLINTA'],
    ),
    IpTaxonomy(
      id: 'shinwoo',
      displayName: 'Shinwoo',
      brandId: 'finding_unicorn',
      aliases: ['SHINWOO'],
    ),
    // TNT SPACE
    IpTaxonomy(
      id: 'rayan',
      displayName: 'Rayan',
      brandId: 'tntspace',
      aliases: ['RAYAN'],
    ),
    IpTaxonomy(
      id: 'dora',
      displayName: 'Dora',
      brandId: 'tntspace',
      aliases: ['DORA'],
    ),
    IpTaxonomy(
      id: 'zoraa',
      displayName: 'Zoraa',
      brandId: 'tntspace',
      aliases: ['ZORAA'],
    ),
    IpTaxonomy(
      id: 'anmoo',
      displayName: 'Anmoo',
      brandId: 'tntspace',
      aliases: ['ANMOO'],
    ),
    IpTaxonomy(
      id: 'liila',
      displayName: 'Liila',
      brandId: 'tntspace',
      aliases: ['LIILA', 'LIITA'],
    ),
    // TOPTOY
    IpTaxonomy(
      id: 'nommi',
      displayName: 'Nommi',
      brandId: 'toptoy',
      aliases: ['NOMMI'],
    ),
    IpTaxonomy(
      id: 'maymei',
      displayName: 'Maymei',
      brandId: 'toptoy',
      aliases: ['MAYMEI'],
    ),
  ];
}
