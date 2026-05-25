const url = process.argv[2];
const html = await (await fetch(url, { headers: { 'User-Agent': 'Mozilla/5.0' } })).text();
const m = html.match(/<script id="__NEXT_DATA__"[^>]*>([\s\S]*?)<\/script>/);
if (!m) {
  console.log('no data');
  process.exit(1);
}
const data = JSON.parse(m[1]);
const hits = [];
function walk(o, path = '') {
  if (!o || typeof o !== 'object') return;
  if (Array.isArray(o)) {
    o.forEach((v, i) => walk(v, `${path}[${i}]`));
    return;
  }
  for (const [k, v] of Object.entries(o)) {
    const p = path ? `${path}.${k}` : k;
    if (
      typeof v === 'string' &&
      /^https:\/\/cdn-global/i.test(v) &&
      /\.(png|jpg|jpeg|webp)/i.test(v) &&
      !v.includes('192.png') &&
      !v.includes('_next/')
    ) {
      hits.push({ p, v });
    }
    walk(v, p);
  }
}
walk(data);
const str = JSON.stringify(data);
const idHits = [...str.matchAll(/https?:\\\/\\\/[^"\\]+/g)]
  .map((x) => x[0].replace(/\\\//g, '/'))
  .filter((u) => u.includes('cdn') && /\.(png|jpg|jpeg|webp)/i.test(u));
console.log('images', JSON.stringify(hits.slice(0, 12), null, 2));
console.log('cdn sample', [...new Set(idHits)].slice(0, 8));
