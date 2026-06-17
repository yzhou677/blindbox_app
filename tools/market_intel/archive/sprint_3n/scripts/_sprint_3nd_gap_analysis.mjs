#!/usr/bin/env node
/** Sprint 3N-D — production vs seed gap by brand/IP/category */
import { readFileSync } from 'node:fs';
import { join } from 'node:path';

const repoRoot = join(import.meta.dirname, '..', '..');
const prodRoot = join(repoRoot, '..', 'blindbox-catalog');

function loadJson(path) {
  return JSON.parse(readFileSync(path, 'utf8'));
}

const prod = {
  figures: loadJson(join(prodRoot, 'data', 'figures.json')),
  series: loadJson(join(prodRoot, 'data', 'series.json')),
  brands: loadJson(join(prodRoot, 'data', 'brands.json')),
  ips: loadJson(join(prodRoot, 'data', 'ips.json')),
};
const seed = {
  figures: loadJson(join(repoRoot, 'tools/seed/figures.json')),
  series: loadJson(join(repoRoot, 'tools/seed/series.json')),
};

const seedFigureIds = new Set(seed.figures.map((f) => f.id));
const seedSeriesIds = new Set(seed.series.map((s) => s.id));
const seriesById = new Map(prod.series.map((s) => [s.id, s]));
const ipById = new Map(prod.ips.map((i) => [i.id, i]));
const brandById = new Map(prod.brands.map((b) => [b.id, b]));

const missingFigures = prod.figures.filter((f) => !seedFigureIds.has(f.id));
const missingSeries = prod.series.filter((s) => !seedSeriesIds.has(s.id));

function categorizeSeries(series) {
  const name = `${series.id} ${series.displayName}`.toLowerCase();
  if (series.isBlindBox === false) return 'standalone_non_blindbox';
  if (/\bmega\b|400%|1000%|100%/.test(name)) return 'mega_scale';
  if (/statue|figurine|plush doll|action figure/.test(name) && !/blind box|pendant|vinyl plush pendant/.test(name))
    return 'statue_figurine';
  if (/plush/.test(name) && !/blind box|pendant/.test(name)) return 'plush_non_blindbox';
  if (/blind box|vinyl plush pendant|vinyl face/.test(name)) return 'blind_box';
  return 'other';
}

function categorizeFigure(figure) {
  const series = seriesById.get(figure.seriesId);
  const name = `${figure.id} ${figure.displayName}`.toLowerCase();
  if (series?.isBlindBox === false) return 'standalone_non_blindbox';
  if (/\bmega\b|400%|1000%|100%/.test(name)) return 'mega_scale';
  if (figure.isSecret) return 'secret_chase';
  return categorizeSeries(series ?? { displayName: '', id: '' });
}

function tallyByIp(figures) {
  const counts = new Map();
  for (const f of figures) {
    const series = seriesById.get(f.seriesId);
    const ipId = series?.ipId ?? f.ipId ?? 'unknown';
    const ip = ipById.get(ipId);
    const label = ip?.displayName ?? ipId;
    counts.set(label, (counts.get(label) ?? 0) + 1);
  }
  return [...counts.entries()].sort((a, b) => b[1] - a[1]);
}

function tallyByBrand(figures) {
  const counts = new Map();
  for (const f of figures) {
    const brand = brandById.get(f.brandId);
    const label = brand?.displayName ?? f.brandId;
    counts.set(label, (counts.get(label) ?? 0) + 1);
  }
  return [...counts.entries()].sort((a, b) => b[1] - a[1]);
}

function tallyCategory(figures) {
  const counts = new Map();
  for (const f of figures) {
    const cat = categorizeFigure(f);
    counts.set(cat, (counts.get(cat) ?? 0) + 1);
  }
  return Object.fromEntries([...counts.entries()].sort((a, b) => b[1] - a[1]));
}

const ipKeywords = ['labubu', 'crybaby', 'skullpanda', 'hirono', 'dimoo', 'molly', 'zsiga'];
const ipMissing = {};
for (const kw of ipKeywords) {
  const prodCount = prod.figures.filter((f) => {
    const s = seriesById.get(f.seriesId);
    const ip = ipById.get(s?.ipId ?? '');
    const hay = `${f.id} ${f.displayName} ${s?.displayName} ${ip?.displayName} ${ip?.id}`.toLowerCase();
    return hay.includes(kw);
  }).length;
  const missingCount = missingFigures.filter((f) => {
    const s = seriesById.get(f.seriesId);
    const ip = ipById.get(s?.ipId ?? '');
    const hay = `${f.id} ${f.displayName} ${s?.displayName} ${ip?.displayName} ${ip?.id}`.toLowerCase();
    return hay.includes(kw);
  }).length;
  ipMissing[kw] = { prodFigures: prodCount, missingFromSeed: missingCount };
}

console.log(
  JSON.stringify(
    {
      totals: {
        prodFigures: prod.figures.length,
        seedFigures: seed.figures.length,
        missingFigures: missingFigures.length,
        missingSeries: missingSeries.length,
      },
      missingByBrand: tallyByBrand(missingFigures),
      missingByIp: tallyByIp(missingFigures),
      missingByCategory: tallyCategory(missingFigures),
      prodByCategory: tallyCategory(prod.figures),
      ipKeywordMissing: ipMissing,
      missingNonBlindSeries: missingSeries
        .filter((s) => s.isBlindBox === false)
        .map((s) => ({ id: s.id, name: s.displayName })),
      missingMegaSeries: missingSeries
        .filter((s) => /mega|400|1000/i.test(`${s.id} ${s.displayName}`))
        .map((s) => ({ id: s.id, name: s.displayName, figures: prod.figures.filter((f) => f.seriesId === s.id).length })),
    },
    null,
    2,
  ),
);
