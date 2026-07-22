import path from 'node:path';
import { RetrievalCalibrationInputLoader } from '../lib/figureRecognition/retrievalCalibrationInput.js';
import { generateCalibrationPolicies, evaluateCalibrationPolicy, calibrationDiagnostics } from '../lib/figureRecognition/retrievalCalibrationAnalyzer.js';
import { compareCalibrationPolicies, paretoPolicies, shortlist } from '../lib/figureRecognition/retrievalCalibrationRanking.js';
import { writeCalibrationOutputs } from '../lib/figureRecognition/retrievalCalibrationWriter.js';
import { RETRIEVAL_CALIBRATION_CONFIG as config } from '../lib/figureRecognition/retrievalCalibrationConfig.js';
import { analyzeRetrievalQuality, formatRetrievalQuality } from '../lib/figureRecognition/retrievalQualityAnalyzer.js';

function args(argv){let input,outputDir,overwrite=false;for(let i=0;i<argv.length;i++){if(argv[i]==='--input')input=argv[++i];else if(argv[i]==='--output-dir')outputDir=argv[++i];else if(argv[i]==='--overwrite')overwrite=true;else throw new Error(`Unsupported argument: ${argv[i]}`);}if(!input||!outputDir)throw new Error('Usage: npm run calibrate:figure-retrieval -- --input <evaluation-results.json> --output-dir <directory> [--overwrite]');return{input:path.resolve(input),outputDir:path.resolve(outputDir),overwrite};}
try { const options=args(process.argv.slice(2));const {samples,summary:inputSummary}=await new RetrievalCalibrationInputLoader().load(options.input);if(!samples.length)throw new Error('No eligible completed evaluation results remain after exclusions');
 const results=generateCalibrationPolicies().map(p=>evaluateCalibrationPolicy(samples,p)).sort(compareCalibrationPolicies);const limit=config.shortlistLimit;
 const zero=results.filter(r=>r.metrics.falseAcceptCount===0);const maxZeroCoverage=zero.length?Math.max(...zero.map(x=>x.metrics.highConfidenceCoverage)):-1;
 const retrievalQuality=analyzeRetrievalQuality(samples);
 const summary={analyzerVersion:config.analyzerVersion,generatedAt:new Date().toISOString(),input:inputSummary,candidatePolicyCount:results.length,retrievalQuality,shortlists:{zeroFalseAccept:shortlist(results,samples,r=>r.metrics.falseAcceptCount===0,limit),highestCoverageZeroFalseAccept:shortlist(results,samples,r=>r.metrics.falseAcceptCount===0&&r.metrics.highConfidenceCoverage===maxZeroCoverage,limit),precisionAtLeast99:shortlist(results,samples,r=>(r.metrics.highConfidencePrecision??0)>=.99,limit),precisionAtLeast95:shortlist(results,samples,r=>(r.metrics.highConfidencePrecision??0)>=.95,limit),pareto:paretoPolicies(results).slice(0,limit).map(r=>({...r,diagnostics:calibrationDiagnostics(samples,r)}))},caveats:config.caveats};
 const files=await writeCalibrationOutputs(options.outputDir,results,summary,options.overwrite);console.log(JSON.stringify({success:true,evaluatedCases:samples.length,candidatePolicies:results.length,outputDirectory:options.outputDir,files},null,2));
 for(const line of formatRetrievalQuality(retrievalQuality))console.log(line);
} catch(error){console.error(JSON.stringify({success:false,errorCode:'retrieval-calibration-failed',reason:error instanceof Error?error.message:'Unknown error'}));process.exitCode=1;}
