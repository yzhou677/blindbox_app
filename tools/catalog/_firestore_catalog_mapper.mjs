/**
 * Node port of lib/features/catalog/firestore/firestore_catalog_mapper.dart.
 * Pure mapping — no Firebase SDK dependency.
 */

/**
 * @param {unknown} value
 * @returns {string}
 */
function readString(value) {
  if (typeof value === 'string') return value.trim();
  return '';
}

/**
 * Mirrors catalogReadStringList in catalog_json_support.dart.
 *
 * @param {unknown} value
 * @returns {string[]}
 */
function readStringList(value) {
  if (!Array.isArray(value)) return [];
  return value
    .map((entry) => readString(entry))
    .filter((entry) => entry.length > 0);
}

/**
 * @param {{ toDate: () => Date }} timestamp
 * @returns {string}
 */
export function timestampToCatalogDate(timestamp) {
  const d = timestamp.toDate();
  const y = String(d.getUTCFullYear()).padStart(4, '0');
  const m = String(d.getUTCMonth() + 1).padStart(2, '0');
  const day = String(d.getUTCDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

/**
 * @param {string} docId
 * @param {Record<string, unknown>} data
 * @returns {Record<string, unknown>}
 */
export function firestoreCatalogDocToJsonMap(docId, data) {
  const out = { ...data };

  const existingId = readString(out.id);
  out.id = existingId || docId;

  const rd = out.releaseDate;
  if (rd != null && typeof rd === 'object' && typeof rd.toDate === 'function') {
    out.releaseDate = timestampToCatalogDate(rd);
  } else if (rd == null) {
    out.releaseDate = null;
  }

  const sortOrder = out.sortOrder;
  if (typeof sortOrder === 'number' && !Number.isInteger(sortOrder)) {
    out.sortOrder = Math.trunc(sortOrder);
  }

  return out;
}

/**
 * @param {Record<string, unknown>} brand
 * @returns {boolean}
 */
export function isUsableBrand(brand) {
  return readString(brand.id) !== '' && readString(brand.displayName) !== '';
}

/**
 * @param {Record<string, unknown>} ip
 * @returns {boolean}
 */
export function isUsableIp(ip) {
  return (
    readString(ip.id) !== '' &&
    readString(ip.brandId) !== '' &&
    readString(ip.displayName) !== ''
  );
}

/**
 * @param {Record<string, unknown>} series
 * @returns {boolean}
 */
export function isUsableSeries(series) {
  return (
    readString(series.id) !== '' &&
    readString(series.brandId) !== '' &&
    readString(series.ipId) !== '' &&
    readString(series.displayName) !== '' &&
    readString(series.imageKey) !== ''
  );
}

/**
 * @param {Record<string, unknown>} figure
 * @returns {boolean}
 */
export function isUsableFigure(figure) {
  return (
    readString(figure.id) !== '' &&
    readString(figure.seriesId) !== '' &&
    readString(figure.brandId) !== '' &&
    readString(figure.ipId) !== '' &&
    readString(figure.displayName) !== '' &&
    readString(figure.imageKey) !== ''
  );
}

/**
 * @param {string} docId
 * @param {Record<string, unknown>} data
 * @returns {Record<string, unknown> | null}
 */
export function mapFirestoreBrand(docId, data) {
  const mapped = firestoreCatalogDocToJsonMap(docId, data);
  return isUsableBrand(mapped) ? mapped : null;
}

/**
 * @param {string} docId
 * @param {Record<string, unknown>} data
 * @returns {Record<string, unknown> | null}
 */
export function mapFirestoreIp(docId, data) {
  const mapped = firestoreCatalogDocToJsonMap(docId, data);
  return isUsableIp(mapped) ? mapped : null;
}

/**
 * @param {string} docId
 * @param {Record<string, unknown>} data
 * @returns {Record<string, unknown> | null}
 */
export function mapFirestoreSeries(docId, data) {
  const mapped = firestoreCatalogDocToJsonMap(docId, data);
  return isUsableSeries(mapped) ? mapped : null;
}

/**
 * @param {string} docId
 * @param {Record<string, unknown>} data
 * @returns {Record<string, unknown> | null}
 */
export function mapFirestoreFigure(docId, data) {
  const mapped = firestoreCatalogDocToJsonMap(docId, data);
  if (!isUsableFigure(mapped)) return null;

  const aliases = readStringList(mapped.aliases);
  if (aliases.length > 0) {
    mapped.aliases = aliases;
  } else {
    delete mapped.aliases;
  }

  return mapped;
}

/**
 * Mirrors firestore_catalog_loader.dart series ordering.
 *
 * @param {Record<string, unknown>} a
 * @param {Record<string, unknown>} b
 * @param {number} [orderA]
 * @param {number} [orderB]
 * @returns {number}
 */
export function compareSeriesSnapshotOrder(a, b, orderA, orderB) {
  const da = typeof a.releaseDate === 'string' ? a.releaseDate : null;
  const db = typeof b.releaseDate === 'string' ? b.releaseDate : null;

  if (da && db) {
    const byDate = db.localeCompare(da);
    if (byDate !== 0) return byDate;
  } else if (da) {
    return -1;
  } else if (db) {
    return 1;
  }

  if (orderA != null && orderB != null) {
    return orderB - orderA;
  }

  return String(b.id).localeCompare(String(a.id));
}

/**
 * @param {import('firebase-admin').firestore.QuerySnapshot | { docs: Array<{ id: string, data: () => Record<string, unknown> }> }} snap
 * @returns {Record<string, unknown>[]}
 */
export function mapBrandSnapshot(snap) {
  /** @type {Record<string, unknown>[]} */
  const out = [];
  for (const doc of snap.docs) {
    const mapped = mapFirestoreBrand(doc.id, doc.data());
    if (mapped) out.push(mapped);
  }
  out.sort((left, right) => String(left.id).localeCompare(String(right.id)));
  return out;
}

/**
 * @param {import('firebase-admin').firestore.QuerySnapshot | { docs: Array<{ id: string, data: () => Record<string, unknown> }> }} snap
 * @returns {Record<string, unknown>[]}
 */
export function mapIpSnapshot(snap) {
  /** @type {Record<string, unknown>[]} */
  const out = [];
  for (const doc of snap.docs) {
    const mapped = mapFirestoreIp(doc.id, doc.data());
    if (mapped) out.push(mapped);
  }
  out.sort((left, right) => String(left.id).localeCompare(String(right.id)));
  return out;
}

/**
 * @param {import('firebase-admin').firestore.QuerySnapshot | { docs: Array<{ id: string, data: () => Record<string, unknown> }> }} snap
 * @returns {Record<string, unknown>[]}
 */
export function mapSeriesSnapshot(snap) {
  /** @type {Array<{ docOrder: number, series: Record<string, unknown> }>} */
  const out = [];
  snap.docs.forEach((doc, index) => {
    const mapped = mapFirestoreSeries(doc.id, doc.data());
    if (mapped) out.push({ docOrder: index, series: mapped });
  });
  out.sort((left, right) =>
    compareSeriesSnapshotOrder(
      left.series,
      right.series,
      left.docOrder,
      right.docOrder,
    ),
  );
  return out.map((entry) => entry.series);
}

/**
 * @param {import('firebase-admin').firestore.QuerySnapshot | { docs: Array<{ id: string, data: () => Record<string, unknown> }> }} snap
 * @returns {Record<string, unknown>[]}
 */
export function mapFigureSnapshot(snap) {
  /** @type {Record<string, unknown>[]} */
  const out = [];
  for (const doc of snap.docs) {
    const mapped = mapFirestoreFigure(doc.id, doc.data());
    if (mapped) out.push(mapped);
  }
  out.sort((left, right) => String(left.id).localeCompare(String(right.id)));
  return out;
}
