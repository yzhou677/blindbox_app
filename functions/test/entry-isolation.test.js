const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const indexPath = path.join(__dirname, '..', 'lib', 'index.js');

/**
 * Top-level CommonJS requires in the compiled entry (module load / cold start).
 * Dynamic `import()` compiles to `require(...)` inside async functions — those
 * must not appear at the outermost module scope.
 */
function topLevelRequireSpecifiers(source) {
  const lines = source.split(/\r?\n/);
  const specs = [];
  let depth = 0;
  for (const line of lines) {
    const opens = (line.match(/\{/g) || []).length;
    const closes = (line.match(/\}/g) || []).length;
    if (depth === 0) {
      const match = line.match(
        /^\s*(?:const|let|var)\s+\w+\s*=\s*require\((['"])(.+?)\1\)/,
      );
      if (match) specs.push(match[2]);
    }
    depth += opens - closes;
  }
  return specs;
}

test('compiled index keeps bounded contexts off the cold-start require graph', () => {
  assert.ok(fs.existsSync(indexPath), 'run npm run build before this test');
  const source = fs.readFileSync(indexPath, 'utf8');
  const topLevel = topLevelRequireSpecifiers(source);

  const forbidden = [
    './marketBrowseRouter',
    './marketItemRouter',
    './recommendationsRouter',
    './recognizeFigureCallable',
    './subjectLocatorCallable',
    './providers/ebay/ebayBrowse',
    './providers/mercari/mercariBrowse',
    './recommendations/ruleEngine',
    './recommendations/catalogFingerprint',
  ];

  for (const spec of forbidden) {
    assert.ok(
      !topLevel.includes(spec),
      `cold-start must not top-level require ${spec}; got: ${topLevel.join(', ')}`,
    );
  }

  // Dynamic graphs must still be present for first-request load.
  for (const spec of [
    './recognizeFigureCallable',
    './subjectLocatorCallable',
    './marketBrowseRouter',
    './recommendationsRouter',
  ]) {
    assert.ok(
      source.includes(spec),
      `entry must still reference ${spec} via lazy import`,
    );
  }
});
