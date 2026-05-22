import 'package:blindbox_app/features/catalog/models/catalog_brand.dart';
import 'package:blindbox_app/features/catalog/models/catalog_figure.dart';
import 'package:blindbox_app/features/catalog/models/catalog_ip.dart';
import 'package:blindbox_app/features/catalog/models/catalog_json_support.dart';
import 'package:blindbox_app/features/catalog/models/catalog_series.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Normalizes one Firestore document into the JSON-shaped [Map] expected by
/// catalog `fromJson` factories. Document id is the canonical id when `id` is
/// missing or empty in fields.
Map<String, dynamic> firestoreCatalogDocToJsonMap(String docId, Map<String, dynamic> data) {
  final out = Map<String, dynamic>.from(data);

  final existingId = catalogReadString(out, 'id');
  out['id'] = existingId.isNotEmpty ? existingId : docId;

  final rd = out['releaseDate'];
  if (rd is Timestamp) {
    out['releaseDate'] = _timestampToCatalogDate(rd);
  } else if (rd == null) {
    out['releaseDate'] = null;
  }

  // Firestore may store numbers as [double].
  final so = out['sortOrder'];
  if (so is double) {
    out['sortOrder'] = so.toInt();
  }

  return out;
}

bool _hasText(String? value) => value != null && value.trim().isNotEmpty;

bool _isUsableBrand(CatalogBrand b) => _hasText(b.id) && _hasText(b.displayName);

bool _isUsableIp(CatalogIp ip) =>
    _hasText(ip.id) && _hasText(ip.brandId) && _hasText(ip.displayName);

bool _isUsableSeries(CatalogSeries s) =>
    _hasText(s.id) &&
    _hasText(s.brandId) &&
    _hasText(s.ipId) &&
    _hasText(s.displayName) &&
    _hasText(s.imageKey);

bool _isUsableFigure(CatalogFigure f) =>
    _hasText(f.id) &&
    _hasText(f.seriesId) &&
    _hasText(f.brandId) &&
    _hasText(f.ipId) &&
    _hasText(f.displayName) &&
    _hasText(f.imageKey);

String _timestampToCatalogDate(Timestamp ts) {
  final d = ts.toDate().toUtc();
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

CatalogBrand? mapFirestoreBrand(String docId, Map<String, dynamic> data) {
  try {
    final mapped = CatalogBrand.fromJson(firestoreCatalogDocToJsonMap(docId, data));
    if (!_isUsableBrand(mapped)) return null;
    return mapped;
  } on Object {
    return null;
  }
}

CatalogIp? mapFirestoreIp(String docId, Map<String, dynamic> data) {
  try {
    final mapped = CatalogIp.fromJson(firestoreCatalogDocToJsonMap(docId, data));
    if (!_isUsableIp(mapped)) return null;
    return mapped;
  } on Object {
    return null;
  }
}

CatalogSeries? mapFirestoreSeries(String docId, Map<String, dynamic> data) {
  try {
    final mapped = CatalogSeries.fromJson(firestoreCatalogDocToJsonMap(docId, data));
    if (!_isUsableSeries(mapped)) return null;
    return mapped;
  } on Object {
    return null;
  }
}

CatalogFigure? mapFirestoreFigure(String docId, Map<String, dynamic> data) {
  try {
    final mapped = CatalogFigure.fromJson(firestoreCatalogDocToJsonMap(docId, data));
    if (!_isUsableFigure(mapped)) return null;
    return mapped;
  } on Object {
    return null;
  }
}
