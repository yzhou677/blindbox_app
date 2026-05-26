#!/usr/bin/env node
const urls = process.argv.slice(2);
for (const url of urls) {
  try {
    const res = await fetch(url, { headers: { 'User-Agent': 'Mozilla/5.0' } });
    const html = await res.text();
    const imgs = [
      ...html.matchAll(/https:\/\/[^"'\\s>]+\.(?:jpg|jpeg|png|webp)(?:\?[^"'\\s>]*)?/gi),
    ]
      .map((m) => m[0])
      .filter(
        (u) =>
          !u.includes('logo') &&
          !u.includes('favicon') &&
          !u.includes('192.png') &&
          (u.includes('cdn/shop') ||
            u.includes('i5.walmartimages') ||
            u.includes('popmart') ||
            u.includes('mynekoshop')),
      );
    console.log(JSON.stringify({ url, images: [...new Set(imgs)].slice(0, 6) }));
  } catch (err) {
    console.log(JSON.stringify({ url, error: String(err.message ?? err) }));
  }
}
