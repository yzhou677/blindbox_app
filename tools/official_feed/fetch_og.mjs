#!/usr/bin/env node
const urls = process.argv.slice(2);
for (const url of urls) {
  try {
    const res = await fetch(url, { headers: { 'User-Agent': 'Mozilla/5.0' } });
    const html = await res.text();
    const og =
      html.match(/property="og:image"\s+content="([^"]+)"/)?.[1] ??
      html.match(/content="([^"]+)"\s+property="og:image"/)?.[1];
    console.log(JSON.stringify({ url, og }));
  } catch (err) {
    console.log(JSON.stringify({ url, error: String(err.message ?? err) }));
  }
}
