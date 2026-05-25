#!/usr/bin/env node
const urls = process.argv.slice(2);
for (const url of urls) {
  try {
    const res = await fetch(url, {
      method: 'GET',
      redirect: 'manual',
      headers: { 'User-Agent': 'Mozilla/5.0' },
      signal: AbortSignal.timeout(15000),
    });
    const loc = res.headers.get('location');
    const body = await res.text();
    const bad = body.includes('not available') || body.includes('BACK TO HOMEPAGE');
    const segment = url.split('/us/products/')[1]?.split('/')[0] ?? '';
    const numericId = /^\d+$/.test(segment);
    console.log(
      JSON.stringify({
        url,
        status: res.status,
        redirect: loc,
        numericId,
        bad,
        len: body.length,
      }),
    );
  } catch (e) {
    console.log(JSON.stringify({ url, error: e.message }));
  }
}
