import { execSync } from 'child_process';
import { ServerMetrics } from './types';

export function parseMetric(file: string, metric: string): number | null {
  try {
    const command = `grep "${metric}" "${file}" | awk '{print $2}' | sed 's/ms//'`;
    const result = execSync(command, { encoding: 'utf-8' }).trim();
    return parseFloat(result);
  } catch (error) {
    console.error(`Error parsing metric from ${file}: ${(error as Error).message}`);
    return null;
  }
}

export function calculateAverage(values: number[]): number {
  if (values.length === 0) return 0;
  const sum = values.reduce((a, b) => a + b, 0);
  return sum / values.length;
}

export function parseServerMetrics(servers: string[], resultFiles: string[]): Record<string, ServerMetrics> {
  const serverMetrics: Record<string, ServerMetrics> = {};

  servers.forEach((server, idx) => {
    const startIdx = idx * 3;
    const reqSecVals: number[] = [];
    const latencyVals: number[] = [];
    for (let j = 0; j < 3; j++) {
      const fileIdx = startIdx + j;
      if (fileIdx < resultFiles.length) {
        const reqSec = parseMetric(resultFiles[fileIdx], "Requests/sec");
        const latency = parseMetric(resultFiles[fileIdx], "Latency");
        if (reqSec !== null) reqSecVals.push(reqSec);
        if (latency !== null) latencyVals.push(latency);
      }
    }
    serverMetrics[server] = {
      reqSec: calculateAverage(reqSecVals),
      latency: calculateAverage(latencyVals)
    };
  });

  return serverMetrics;
}
