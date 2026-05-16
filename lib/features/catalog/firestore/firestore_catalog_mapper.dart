import 'package:blindbox_app/features/catalog/models/catalog_brand.dart';
import 'package:blindbox_app/features/catalog/models/catalog_figure.dart';
import 'package:blindbox_app/features/catalog/models/catalog_ip.dart';
import 'package:blindbox_app/features/catalog/models/catalog_json_support.dart';
import 'package:blindbox_app/features/catalog/models/catalog_series.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

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
  }

  // Firestore may store numbers as [double].
  final so = out['sortOrder'];
  if (so is double) {
    out['sortOrder'] = so.toInt();
  }

  return out;
}

String _timestampToCatalogDate(Timestamp ts) {
  final d = ts.toDate().toUtc();
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

CatalogBrand? mapFirestoreBrand(String docId, Map<String, dynamic> data) {
  try {
    return CatalogBrand.fromJson(firestoreCatalogDocToJsonMap(docId, data));
  } on Object catch (e, st) {
    debugPrint('mapFirestoreBrand failed for $docId: $e\n$st');
    return null;
  }
}

CatalogIp? mapFirestoreIp(String docId, Map<String, dynamic> data) {
  try {
    return CatalogIp.fromJson(firestoreCatalogDocToJsonMap(docId, data));
  } on Object catch (e, st) {
    debugPrint('mapFirestoreIp failed for $docId: $e\n$st');
    return null;
  }
}

CatalogSeries? mapFirestoreSeries(String docId, Map<String, dynamic> data) {
  try {
    return CatalogSeries.fromJson(firestoreCatalogDocToJsonMap(docId, data));
  } on Object catch (e, st) {
    debugPrint('mapFirestoreSeries failed for $docId: $e\n$st');
    return null;
  }
}

CatalogFigure? mapFirestoreFigure(String docId, Map<String, dynamic> data) {
  try {
    return CatalogFigure.fromJson(firestoreCatalogDocToJsonMap(docId, data));
  } on Object catch (e, st) {
    debugPrint('mapFirestoreFigure failed for $docId: $e\n$st');
    return null;
  }
}
