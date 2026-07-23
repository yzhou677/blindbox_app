import { AsyncLocalStorage } from 'node:async_hooks';
import { logger } from 'firebase-functions';

export type ScanTimingComponent = 'backend_locator' | 'backend_recognition';

type ScanTimingContext = {
  component: ScanTimingComponent;
  correlationId: string;
};

const context = new AsyncLocalStorage<ScanTimingContext>();

export function withScanTimingContext<T>(
  value: ScanTimingContext,
  operation: () => Promise<T>,
): Promise<T> {
  return context.run(value, operation);
}

export async function measureScanStage<T>(
  stage: string,
  operation: () => T | Promise<T>,
  safeFields: Record<string, string | number | boolean | undefined> = {},
): Promise<T> {
  const startedAt = process.hrtime.bigint();
  try {
    return await operation();
  } finally {
    logScanStage(stage, elapsedMs(startedAt), safeFields);
  }
}

export function measureScanStageSync<T>(
  stage: string,
  operation: () => T,
  safeFields: Record<string, string | number | boolean | undefined> = {},
): T {
  const startedAt = process.hrtime.bigint();
  try {
    return operation();
  } finally {
    logScanStage(stage, elapsedMs(startedAt), safeFields);
  }
}

export function logScanStage(
  stage: string,
  durationMs: number,
  safeFields: Record<string, string | number | boolean | undefined> = {},
): void {
  const active = context.getStore();
  if (!active) return;
  logger.debug('Figure scan timing', {
    component: active.component,
    correlationId: active.correlationId,
    stage,
    elapsedMs: durationMs,
    ...safeFields,
  });
}

function elapsedMs(startedAt: bigint): number {
  return Number(process.hrtime.bigint() - startedAt) / 1_000_000;
}
