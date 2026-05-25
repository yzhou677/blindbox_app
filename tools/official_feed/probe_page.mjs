const url = process.argv[2];
const html = await (await fetch(url, { headers: { 'User-Agent': 'Mozilla/5.0' } })).text();
const m = html.match(/<script id="__NEXT_DATA__"[^>]*>([\s\S]*?)<\/script>/);
if (!m) {
  console.log('no __NEXT_DATA__');
  process.exit(1);
}
const data = JSON.parse(m[1]);
const str = JSON.stringify(data);
const imgs = [...str.matchAll(/https:\\\/\\\/cdn-global[^"\\]+?\.(?:png|jpg|jpeg|webp)/g)]
  .map((x) => x[0].replace(/\\\//g, '/'))
  .filter((u) => !u.includes('/images/192.png') && !u.includes('_next/'));
console.log([...new Set(imgs)].slice(0, 8));
