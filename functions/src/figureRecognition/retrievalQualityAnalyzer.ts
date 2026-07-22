import type { CalibrationInputSample, RetrievalHardFailure, RetrievalQualityGroup, RetrievalQualityReport } from './retrievalCalibrationTypes';

export function analyzeRetrievalQuality(samples: readonly CalibrationInputSample[]): RetrievalQualityReport {
  const present = samples.filter((sample) => sample.catalogPresence === 'present');
  const absent = samples.filter((sample) => sample.catalogPresence === 'absent');
  const presentMetrics = metrics(present);
  const hardFailures: RetrievalHardFailure[] = present.filter((sample) => !sample.top1Correct).map((sample) => ({
    caseId: sample.id, expectedFigureId: sample.expectedFigureId!, expectedSeriesId: sample.expectedSeriesId ?? 'unknown', expectedIpId: sample.expectedIpId ?? 'unknown',
    retrievedTop1FigureId: sample.top1FigureId, retrievedTop1SeriesId: sample.top1SeriesId, retrievedTop1IpId: sample.top1IpId,
    correctRank: sample.expectedRank, top1Distance: sample.top1Distance,
  })).sort((a, b) => (a.correctRank ?? Number.POSITIVE_INFINITY) - (b.correctRank ?? Number.POSITIVE_INFINITY) || a.top1Distance - b.top1Distance || a.caseId.localeCompare(b.caseId));
  const accuracyByIp = groups(present, (sample) => sample.expectedIpId ?? 'unknown');
  const accuracyBySeries = groups(present, (sample) => sample.expectedSeriesId ?? 'unknown');
  return {
    overall: {
      catalogPresent: { cases: present.length, ...presentMetrics, averageTop1Distance: average(present.map((sample) => sample.top1Distance)), medianTop1Distance: median(present.map((sample) => sample.top1Distance)) },
      catalogAbsent: { cases: absent.length, falseTop1Rate: ratio(absent.filter((sample) => sample.top1FigureId !== undefined).length, absent.length), averageTop1Distance: average(absent.map((sample) => sample.top1Distance)) },
    },
    accuracyByIp, accuracyBySeries, hardFailures,
    summary: { overallTop1: presentMetrics.top1Accuracy, overallTop3: presentMetrics.top3Accuracy, overallTop5: presentMetrics.top5Accuracy, worstPerformingIp: worst(accuracyByIp), worstPerformingSeries: worst(accuracyBySeries), hardFailures: hardFailures.length },
  };
}

function metrics(samples: readonly CalibrationInputSample[]): Omit<RetrievalQualityGroup, 'id' | 'cases'> {
  const ranks = samples.map((sample) => sample.expectedRank);
  const retrievedRanks = ranks.filter((rank): rank is number => rank !== undefined);
  let reciprocalRankTotal = 0; for (const rank of ranks) if (rank !== undefined) reciprocalRankTotal += 1 / rank;
  return { top1Accuracy: ratio(ranks.filter((rank) => rank === 1).length, samples.length), top3Accuracy: ratio(ranks.filter((rank) => rank !== undefined && rank <= 3).length, samples.length), top5Accuracy: ratio(ranks.filter((rank) => rank !== undefined && rank <= 5).length, samples.length), meanReciprocalRank: samples.length ? reciprocalRankTotal / samples.length : 0, averageRank: average(retrievedRanks) };
}
function groups(samples: readonly CalibrationInputSample[], key: (sample: CalibrationInputSample) => string): RetrievalQualityGroup[] { const map = new Map<string, CalibrationInputSample[]>();for(const sample of samples){const id=key(sample);const values=map.get(id)??[];values.push(sample);map.set(id,values);}return [...map].map(([id,values])=>({id,cases:values.length,...metrics(values)})).sort((a,b)=>b.cases-a.cases||a.id.localeCompare(b.id)); }
function worst(groups: readonly RetrievalQualityGroup[]): string | undefined { return groups.filter((group)=>group.id!=='unknown').sort((a,b)=>a.top1Accuracy-b.top1Accuracy||a.top3Accuracy-b.top3Accuracy||a.top5Accuracy-b.top5Accuracy||a.meanReciprocalRank-b.meanReciprocalRank||b.cases-a.cases||a.id.localeCompare(b.id))[0]?.id; }
function ratio(n:number,d:number):number{return d?n/d:0;} function average(values:readonly number[]):number|undefined{return values.length?values.reduce((a,b)=>a+b,0)/values.length:undefined;} function median(values:readonly number[]):number|undefined{if(!values.length)return undefined;const sorted=[...values].sort((a,b)=>a-b),middle=Math.floor(sorted.length/2);return sorted.length%2?sorted[middle]:(sorted[middle-1]+sorted[middle])/2;}

export function formatRetrievalQuality(report: RetrievalQualityReport): string[] {
  const p=report.overall.catalogPresent,a=report.overall.catalogAbsent,percent=(v:number)=>`${v*100}%`;const lines=['Overall Retrieval Quality','','Catalog Present Cases',`Cases: ${p.cases}`,`Top-1 Accuracy: ${percent(p.top1Accuracy)}`,`Top-3 Accuracy: ${percent(p.top3Accuracy)}`,`Top-5 Accuracy: ${percent(p.top5Accuracy)}`,`Mean Reciprocal Rank: ${p.meanReciprocalRank}`,`Average Top-1 Distance: ${String(p.averageTop1Distance)}`,`Median Top-1 Distance: ${String(p.medianTop1Distance)}`,'','Catalog Absent Cases',`Cases: ${a.cases}`,`False Top-1 Rate: ${percent(a.falseTop1Rate)}`,`Average Top-1 Distance: ${String(a.averageTop1Distance)}`,'','Accuracy by IP'];
  appendGroups(lines,report.accuracyByIp,'IP');lines.push('','Accuracy by Series');appendGroups(lines,report.accuracyBySeries,'Series');lines.push('','Hard Retrieval Failures');for(const f of report.hardFailures)lines.push('',`Case: ${f.caseId}`,`Expected Figure: ${f.expectedFigureId}`,`Expected Series: ${f.expectedSeriesId}`,`Expected IP: ${f.expectedIpId}`,'',`Retrieved Top1: ${f.retrievedTop1FigureId??'None'}`,`Retrieved Series: ${f.retrievedTop1SeriesId??'unknown'}`,`Retrieved IP: ${f.retrievedTop1IpId??'unknown'}`,'',`Correct Rank: ${f.correctRank??'Not Retrieved'}`,`Top1 Distance: ${f.top1Distance}`);const s=report.summary;lines.push('','Embedding Quality Summary',`Overall Top1: ${percent(s.overallTop1)}`,`Overall Top3: ${percent(s.overallTop3)}`,`Overall Top5: ${percent(s.overallTop5)}`,`Worst Performing IP: ${s.worstPerformingIp??'None'}`,`Worst Performing Series: ${s.worstPerformingSeries??'None'}`,`Hard Failures: ${s.hardFailures}`);return lines;
}
function appendGroups(lines:string[],groups:readonly RetrievalQualityGroup[],label:string){for(const g of groups)lines.push('',`${label}: ${g.id}`,`Cases: ${g.cases}`,`Top1: ${g.top1Accuracy*100}%`,`Top3: ${g.top3Accuracy*100}%`,`Top5: ${g.top5Accuracy*100}%`,`MRR: ${g.meanReciprocalRank}`,`Average Rank: ${g.averageRank??'Not Retrieved'}`);}
