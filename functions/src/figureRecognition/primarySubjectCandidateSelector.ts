import type { PrimarySubjectConfig } from './primarySubjectConfig';
import { PrimarySubjectCropper, type PreparedCrop, type PreparedImage } from './primarySubjectCropper';
import type { LocatorCandidate, PrimarySubjectCandidateScore } from './primarySubjectTypes';

export type ScoredPrimarySubjectCandidate = { candidate: LocatorCandidate; crop: PreparedCrop; score: PrimarySubjectCandidateScore };
export type PrimarySubjectSelection = { selected: ScoredPrimarySubjectCandidate; candidates: ScoredPrimarySubjectCandidate[] };

/** Deterministically selects one primary from validated, single-collectible proposals. */
export class PrimarySubjectCandidateSelector {
  constructor(private readonly cropper: PrimarySubjectCropper, private readonly config: PrimarySubjectConfig) {}

  async select(prepared: PreparedImage, candidates: LocatorCandidate[]): Promise<PrimarySubjectSelection> {
    if (candidates.length === 0) throw new Error('At least one validated candidate is required');
    const scored = await Promise.all(candidates.map(async (candidate, index) => {
      const crop = await this.cropper.crop(prepared, candidate);
      const score = this.score(candidate, crop, prepared, index);
      return { candidate, crop, score };
    }));
    let selectedIndex = 0;
    for (let index = 1; index < scored.length; index++) {
      if (scored[index].score.totalScore > scored[selectedIndex].score.totalScore) selectedIndex = index;
    }
    for (let index = 0; index < scored.length; index++) scored[index].score.selected = index === selectedIndex;
    return { selected: scored[selectedIndex], candidates: scored };
  }

  private score(candidate: LocatorCandidate, crop: PreparedCrop, source: PreparedImage, index: number): PrimarySubjectCandidateScore {
    const box = candidate.box;
    const centerX = (box.xmin + box.xmax) / 2000;
    const centerY = (box.ymin + box.ymax) / 2000;
    const maxCenterDistance = Math.SQRT1_2;
    const centerScore = clamp01(1 - Math.hypot(centerX - 0.5, centerY - 0.5) / maxCenterDistance);
    const sharpnessScore = clamp01(Math.max(crop.sharpness / this.config.minSharpness, crop.gradientEnergy / this.config.minGradientEnergy));
    const subjectAreaRatio = ((box.xmax - box.xmin) * (box.ymax - box.ymin)) / 1_000_000;
    const areaScore = clamp01(subjectAreaRatio / this.config.candidateAreaScoreSaturation);
    const paddedAreaRatio = (crop.box.width * crop.box.height) / (source.width * source.height);
    const backgroundScore = paddedAreaRatio <= 0 ? 0 : clamp01(subjectAreaRatio / paddedAreaRatio);
    const weights = this.config.candidateScoreWeights;
    const totalScore = centerScore * weights.center + sharpnessScore * weights.sharpness + areaScore * weights.area + backgroundScore * weights.background;
    return {
      candidateNumber: index + 1,
      normalized: box,
      pixels: crop.box,
      centerScore,
      sharpnessScore,
      areaScore,
      backgroundScore,
      totalScore,
      selected: false,
    };
  }
}

function clamp01(value: number): number { return Math.max(0, Math.min(1, value)); }
