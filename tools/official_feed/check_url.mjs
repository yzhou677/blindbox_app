#!/usr/bin/env node
import {
  isPopMartUsProductSpaShell,
  phantomProductProbeUrl,
} from './official_feed_curation.mjs';
import { productIdFromOfficialUrl } from './seed_validation.mjs';

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
    const urlProductId = productIdFromOfficialUrl(url);
    const numericId = urlProductId != null;
    const spaShell = isPopMartUsProductSpaShell(body);
    let phantomAccepted = null;
    if (spaShell && url.includes('/us/products/')) {
      const slug = url.split('/us/products/')[1]?.split('/').slice(1).join('/');
      if (slug) {
        const phantomUrl = phantomProductProbeUrl(slug);
        const pr = await fetch(phantomUrl, {
          method: 'GET',
          headers: { 'User-Agent': 'Mozilla/5.0' },
          signal: AbortSignal.timeout(15000),
        });
        const pb = pr.status === 200 ? await pr.text() : '';
        phantomAccepted = pr.status === 200 && isPopMartUsProductSpaShell(pb);
      }
    }
    console.log(
      JSON.stringify({
        url,
        status: res.status,
        redirect: loc,
        numericId,
        urlProductId,
        bad,
        len: body.length,
        spaShell,
        phantomAccepted,
        idVerifiable: !spaShell && !phantomAccepted,
        note:
          spaShell && phantomAccepted
            ? 'HTTP 200 does not prove productId — verify in browser after hydration'
            : null,
      }),
    );
  } catch (e) {
    console.log(JSON.stringify({ url, error: e.message }));
  }
}
