#!/usr/bin/env node
/**
 * Build / refresh the PR description coverage block.
 *
 * Inputs (env):
 *   LCOV_PATH          — path to lcov.info (default: coverage/lcov.info)
 *   CHANGED_DART_FILES — newline-separated repo-relative Dart paths
 *   PR_NUMBER          — pull request number
 *   GITHUB_TOKEN       — token with pull-requests: write
 *   GITHUB_REPOSITORY  — owner/repo
 *   GITHUB_SHA         — commit SHA for the report footer
 *
 * Behavior:
 *   - Reads the current PR body
 *   - Replaces (or appends) the region between
 *       <!-- coverage:start --> ... <!-- coverage:end -->
 *   - Leaves every other part of the description untouched
 *   - Never fails the job over missing coverage numbers (report-only)
 */
import { readFileSync, existsSync } from 'node:fs';

const START = '<!-- coverage:start -->';
const END = '<!-- coverage:end -->';

function parseLcov(text) {
  /** @type {Map<string, { lf: number, lh: number }>} */
  const files = new Map();
  let current = null;
  let lf = 0;
  let lh = 0;

  for (const raw of text.split(/\r?\n/)) {
    const line = raw.trim();
    if (line.startsWith('SF:')) {
      // Normalize to repo-relative forward-slash paths.
      let path = line.slice(3).replace(/\\/g, '/');
      const marker = '/lib/';
      const libIdx = path.lastIndexOf(marker);
      if (libIdx >= 0) {
        path = path.slice(libIdx + 1); // keep "lib/..."
      } else if (path.includes('/test/')) {
        const testIdx = path.lastIndexOf('/test/');
        path = path.slice(testIdx + 1);
      }
      current = path;
      lf = 0;
      lh = 0;
    } else if (line.startsWith('LF:')) {
      lf = Number(line.slice(3)) || 0;
    } else if (line.startsWith('LH:')) {
      lh = Number(line.slice(3)) || 0;
    } else if (line === 'end_of_record' && current) {
      files.set(current, { lf, lh });
      current = null;
    }
  }
  return files;
}

function pct(lh, lf) {
  if (!lf) return 'n/a';
  return `${((100 * lh) / lf).toFixed(1)}%`;
}

function totals(files) {
  let lf = 0;
  let lh = 0;
  for (const v of files.values()) {
    lf += v.lf;
    lh += v.lh;
  }
  return { lf, lh };
}

function normalizeChangedPath(p) {
  return p.replace(/\\/g, '/').replace(/^\.\//, '');
}

function buildBlock({ overall, perFileRows, sha, note }) {
  const lines = [
    START,
    '## Coverage (auto-generated)',
    '',
    `**Total line coverage:** ${pct(overall.lh, overall.lf)}` +
      ` (${overall.lh}/${overall.lf} lines)`,
    '',
    '### Changed Dart files',
    '',
  ];

  if (perFileRows.length === 0) {
    lines.push('_No changed Dart files with coverage data in this PR._');
  } else {
    lines.push('| File | Coverage | Lines |');
    lines.push('| --- | ---: | ---: |');
    for (const row of perFileRows) {
      lines.push(
        `| \`${row.path}\` | ${row.pct} | ${row.lh}/${row.lf} |`,
      );
    }
  }

  lines.push('');
  lines.push(
    '_Report-only — no coverage gate. Regenerated on each `synchronize`._',
  );
  if (note) {
    lines.push('');
    lines.push(note);
  }
  if (sha) {
    lines.push('');
    lines.push(`Commit: \`${sha.slice(0, 7)}\``);
  }
  lines.push(END);
  return lines.join('\n');
}

function upsertBlock(body, block) {
  const src = body ?? '';
  const startIdx = src.indexOf(START);
  const endIdx = src.indexOf(END);

  if (startIdx >= 0 && endIdx > startIdx) {
    const before = src.slice(0, startIdx);
    const after = src.slice(endIdx + END.length);
    // Preserve a single trailing newline after the block when possible.
    const trimmedAfter = after.replace(/^\r?\n/, '');
    return `${before}${block}\n${trimmedAfter}`;
  }

  const trimmed = src.replace(/\s*$/, '');
  if (!trimmed) return `${block}\n`;
  return `${trimmed}\n\n${block}\n`;
}

async function githubJson(method, urlPath, token, body) {
  const res = await fetch(`https://api.github.com${urlPath}`, {
    method,
    headers: {
      Accept: 'application/vnd.github+json',
      Authorization: `Bearer ${token}`,
      'X-GitHub-Api-Version': '2022-11-28',
      'User-Agent': 'shelfy-pr-coverage',
      ...(body ? { 'Content-Type': 'application/json' } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  let data = null;
  try {
    data = text ? JSON.parse(text) : null;
  } catch {
    data = { raw: text };
  }
  if (!res.ok) {
    throw new Error(
      `GitHub API ${method} ${urlPath} → ${res.status}: ${text.slice(0, 400)}`,
    );
  }
  return data;
}

async function main() {
  const lcovPath = process.env.LCOV_PATH || 'coverage/lcov.info';
  const prNumber = process.env.PR_NUMBER;
  const token = process.env.GITHUB_TOKEN;
  const repo = process.env.GITHUB_REPOSITORY;
  const sha = process.env.GITHUB_SHA || '';

  if (!prNumber || !token || !repo) {
    throw new Error('PR_NUMBER, GITHUB_TOKEN, and GITHUB_REPOSITORY are required');
  }

  const [owner, repoName] = repo.split('/');
  let note = '';
  /** @type {Map<string, { lf: number, lh: number }>} */
  let files = new Map();

  if (!existsSync(lcovPath)) {
    note =
      '_Coverage file missing (`coverage/lcov.info`). Tests may have failed before writing coverage._';
  } else {
    files = parseLcov(readFileSync(lcovPath, 'utf8'));
  }

  const overall = totals(files);
  const changedRaw = (process.env.CHANGED_DART_FILES || '')
    .split(/\r?\n/)
    .map((s) => s.trim())
    .filter(Boolean)
    .map(normalizeChangedPath);

  const perFileRows = [];
  for (const path of changedRaw) {
    // Match SF paths that end with this repo-relative path.
    let hit = files.get(path);
    if (!hit) {
      for (const [sf, stats] of files) {
        if (sf === path || sf.endsWith(`/${path}`) || sf.endsWith(path)) {
          hit = stats;
          break;
        }
      }
    }
    if (!hit) {
      perFileRows.push({
        path,
        pct: 'n/a',
        lh: 0,
        lf: 0,
      });
      continue;
    }
    perFileRows.push({
      path,
      pct: pct(hit.lh, hit.lf),
      lh: hit.lh,
      lf: hit.lf,
    });
  }

  const block = buildBlock({ overall, perFileRows, sha, note });

  const pr = await githubJson(
    'GET',
    `/repos/${owner}/${repoName}/pulls/${prNumber}`,
    token,
  );
  const nextBody = upsertBlock(pr.body || '', block);

  if (nextBody === (pr.body || '')) {
    console.log('PR body already up to date; no patch needed.');
    return;
  }

  await githubJson(
    'PATCH',
    `/repos/${owner}/${repoName}/pulls/${prNumber}`,
    token,
    { body: nextBody },
  );
  console.log(
    `Updated PR #${prNumber} coverage block (total ${pct(overall.lh, overall.lf)}).`,
  );
}

main().catch((err) => {
  console.error(err);
  // Report-only: never fail CI because the description could not be updated.
  process.exit(0);
});
