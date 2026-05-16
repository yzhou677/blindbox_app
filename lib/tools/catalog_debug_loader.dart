import 'package:blindbox_app/features/catalog/catalog_seed_loader.dart';
import 'package:flutter/services.dart';

Future<void> debugLoadCatalog() async {
  final figuresJson = await rootBundle.loadString('tools/seed/figures.json');
  final figures = parseCatalogFiguresJson(figuresJson);
  // ignore: avoid_print
  print(figures);
}
