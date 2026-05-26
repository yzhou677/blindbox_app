#!/usr/bin/env node
/** One-off helper: print og:image from POP MART US product URLs. */
const urls = process.argv.slice(2);
if (urls.length === 0) {
  console.error('Usage: node fetch_popmart_meta.mjs <url> [...]');
  process.exit(1);
}

for (const url of urls) {
  try {
    const res = await fetch(url, {
      headers: { 'User-Agent': 'Mozilla/5.0 (compatible; blindbox-seed/1.0)' },
      signal: AbortSignal.timeout(20000),
    });
    const html = await res.text();
    const og =
      html.match(/property="og:image"\s+content="([^"]+)"/)?.[1] ??
      html.match(/content="([^"]+)"\s+property="og:image"/)?.[1];
    const cdn = [
      ...html.matchAll(
        /https:\/\/cdn-global[^"'\\s>]+\.(?:png|jpg|jpeg|webp)(?:\?[^"'\\s>]*)?/gi,
      ),
    ].map((m) => m[0]);
    const unique = [...new Set(cdn)].filter((u) => !u.includes('192.png')).slice(0, 5);
    console.log(JSON.stringify({ url, status: res.status, ogImage: og ?? null, cdn: unique }));
  } catch (err) {
    console.log(JSON.stringify({ url, error: String(err.message ?? err) }));
  }
}
