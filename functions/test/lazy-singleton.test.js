const assert = require('node:assert/strict');
const test = require('node:test');
const { lazySingleton } = require('../lib/shared/lazySingleton');

test('lazySingleton loads once and reuses the value', async () => {
  let loads = 0;
  const get = lazySingleton(async () => {
    loads += 1;
    return { token: loads };
  });

  const first = await get();
  const second = await get();
  assert.equal(loads, 1);
  assert.strictEqual(first, second);
});

test('lazySingleton coalesces concurrent first loads', async () => {
  let loads = 0;
  const get = lazySingleton(async () => {
    loads += 1;
    await new Promise((resolve) => setTimeout(resolve, 10));
    return { token: loads };
  });

  const [a, b] = await Promise.all([get(), get()]);
  assert.equal(loads, 1);
  assert.strictEqual(a, b);
});
