#!/usr/bin/env node
const ALPHABET =
  'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';
const EPOCH = 1314220021721n;

function shortcodeToMediaId(shortcode) {
  let id = 0n;
  for (const c of shortcode) {
    const idx = ALPHABET.indexOf(c);
    if (idx < 0) throw new Error(`bad char ${c}`);
    id = id * 64n + BigInt(idx);
  }
  return id;
}

function mediaIdToPublishedAt(mediaId) {
  const ms = (mediaId >> 23n) + EPOCH;
  const d = new Date(Number(ms));
  const y = d.getUTCFullYear();
  const m = String(d.getUTCMonth() + 1).padStart(2, '0');
  const day = String(d.getUTCDate()).padStart(2, '0');
  return {
    isoUtc: d.toISOString(),
    isoDay: `${y}-${m}-${day}T00:00:00Z`,
    ms: Number(ms),
    utc: d.toISOString(),
  };
}

const posts = process.argv.slice(2);
for (const shortcode of posts) {
  const mediaId = shortcodeToMediaId(shortcode);
  const pub = mediaIdToPublishedAt(mediaId);
  console.log(JSON.stringify({ shortcode, mediaId: mediaId.toString(), ...pub }));
}
