const assert = require('node:assert/strict');
const { describe, it } = require('node:test');
const {
  FirestoreRecognitionCandidateHydrator,
} = require('../lib/figureRecognition/recognitionCandidateHydrator');

function fakeFirestore(data) {
  const calls = [];
  return {
    calls,
    collection(collection) {
      return { doc: (id) => ({ path: `${collection}/${id}` }) };
    },
    async getAll(...refs) {
      calls.push(refs.map((ref) => ref.path));
      return refs.map((ref) => ({ data: () => data[ref.path] }));
    },
  };
}

const candidates = [
  { rank: 1, figureId: 'f1', seriesId: 's1', ipId: 'i1' },
  { rank: 2, figureId: 'f2', seriesId: 's1', ipId: 'i1' },
  { rank: 3, figureId: 'f3', seriesId: 's2', ipId: 'i1' },
];

describe('recognition candidate hydration', () => {
  it('deduplicates document reads in one batch and preserves candidate order', async () => {
    const firestore = fakeFirestore({
      'figures/f1': { displayName: 'Figure 1', imageKey: 'one' },
      'figures/f2': { displayName: 'Figure 2', imageKey: 'two' },
      'figures/f3': { displayName: 'Figure 3', imageKey: 'three' },
      'series/s1': { displayName: 'Series 1' },
      'series/s2': { displayName: 'Series 2' },
      'ips/i1': { displayName: 'IP 1' },
    });
    const result = await new FirestoreRecognitionCandidateHydrator(
      firestore,
    ).hydrate(candidates);
    assert.equal(firestore.calls.length, 1);
    assert.deepEqual(firestore.calls[0], [
      'figures/f1',
      'series/s1',
      'ips/i1',
      'figures/f2',
      'figures/f3',
      'series/s2',
    ]);
    assert.deepEqual(result.map((candidate) => candidate.figureId), [
      'f1',
      'f2',
      'f3',
    ]);
    assert.deepEqual(result.map((candidate) => candidate.seriesName), [
      'Series 1',
      'Series 1',
      'Series 2',
    ]);
  });

  it('keeps missing hydration data as a sanitized hydration failure', async () => {
    const firestore = fakeFirestore({
      'figures/f1': { displayName: 'Figure 1', imageKey: 'one' },
      'series/s1': { displayName: 'Series 1' },
    });
    await assert.rejects(
      () =>
        new FirestoreRecognitionCandidateHydrator(firestore).hydrate([
          candidates[0],
        ]),
      (error) => error?.name === 'RecognitionHydrationError',
    );
  });
});
