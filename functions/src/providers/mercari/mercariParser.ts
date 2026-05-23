import type { MercariRawItem } from './mercariTypes';

/** Extract listing rows from Mercari search payloads (schema-tolerant). */
export function extractMercariItems(payload: unknown): MercariRawItem[] {
  if (!payload || typeof payload !== 'object') return [];

  const root = payload as MercariRawItem;
  const candidates: unknown[] = [];

  pushArray(candidates, root.items);
  pushArray(candidates, root.data);
  pushArray(candidates, root.results);

  const data = readRecord(root.data);
  if (data) {
    pushArray(candidates, data.items);
    pushArray(candidates, data.searchResults);
    const search = readRecord(data.search);
    if (search) {
      pushArray(candidates, search.items);
      pushArray(candidates, search.edges);
    }
  }

  const itemsField = readRecord(root.items);
  if (itemsField) pushArray(candidates, itemsField.items);

  for (const block of candidates) {
    if (!Array.isArray(block)) continue;
    const rows = block
      .map((entry) => unwrapItem(entry))
      .filter((row): row is MercariRawItem => row != null);
    if (rows.length > 0) return rows;
  }

  return [];
}

function unwrapItem(entry: unknown): MercariRawItem | null {
  if (!entry || typeof entry !== 'object') return null;
  const row = entry as MercariRawItem;
  const node = readRecord(row.node) ?? readRecord(row.item) ?? row;
  return node;
}

function pushArray(target: unknown[], value: unknown): void {
  if (Array.isArray(value)) target.push(value);
}

function readRecord(value: unknown): MercariRawItem | undefined {
  if (value && typeof value === 'object' && !Array.isArray(value)) {
    return value as MercariRawItem;
  }
  return undefined;
}
