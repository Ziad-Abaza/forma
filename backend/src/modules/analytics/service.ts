/**
 * Time-Series Analytics & Trends (ADR-009, §7.7)
 *
 * Requirements:
 * - Noise-robust trends: smoothing body weight and composition.
 * - Temporal rate of change: min data points and window duration enforced.
 * - Rollups and period deltas.
 * - Outlier / anomaly detection.
 */

import { Observation } from '../measurements/model.js';

export interface TrendAnalysisResult {
  metricCode: string;
  count: number;
  dataSufficiency: 'sufficient' | 'insufficient';
  startDate: string;
  endDate: string;
  startValue: number;
  latestValue: number;
  delta: number;
  rateOfChangePerWeek?: number;
  smoothedPoints: Array<{ date: string; value: number }>;
  anomalies: Array<{ observationId: string; date: string; value: number; reason: string }>;
}

export class AnalyticsService {
  /**
   * Calculate moving average and rate of change for a series of observations.
   * Filters out voided or superseded observations.
   */
  static analyzeTrend(observations: Observation[]): TrendAnalysisResult {
    // 1. Filter active observations and sort chronologically
    const active = observations
      .filter((o) => o.status === 'active')
      .sort((a, b) => new Date(a.observedAt).getTime() - new Date(b.observedAt).getTime());

    if (active.length === 0) {
      return {
        metricCode: 'none',
        count: 0,
        dataSufficiency: 'insufficient',
        startDate: '',
        endDate: '',
        startValue: 0,
        latestValue: 0,
        delta: 0,
        smoothedPoints: [],
        anomalies: [],
      };
    }

    const metricCode = active[0].typeCode;
    const startDate = active[0].observedAt;
    const endDate = active[active.length - 1].observedAt;
    const startValue = active[0].canonicalValue;
    const latestValue = active[active.length - 1].canonicalValue;
    const delta = Math.round((latestValue - startValue) * 100) / 100;

    // Detect anomalies: sudden changes exceeding 3.5 kg within 24 hours
    const anomalies: TrendAnalysisResult['anomalies'] = [];
    for (let i = 1; i < active.length; i++) {
      const prev = active[i - 1];
      const curr = active[i];
      const diffDays =
        (new Date(curr.observedAt).getTime() - new Date(prev.observedAt).getTime()) / (1000 * 60 * 60 * 24);
      const valDiff = Math.abs(curr.canonicalValue - prev.canonicalValue);

      if (diffDays <= 1.5 && valDiff > 3.5) {
        anomalies.push({
          observationId: curr.id,
          date: curr.observedAt,
          value: curr.canonicalValue,
          reason: `Sudden jump of ${valDiff.toFixed(1)} ${curr.canonicalUnit} within ${diffDays.toFixed(1)} days`,
        });
      }
    }

    // 2. Exponential or simple 3-point moving average for smoothing
    const smoothedPoints: Array<{ date: string; value: number }> = [];
    const windowSize = 3;
    for (let i = 0; i < active.length; i++) {
      const startIdx = Math.max(0, i - windowSize + 1);
      const slice = active.slice(startIdx, i + 1);
      const avg = slice.reduce((sum, item) => sum + item.canonicalValue, 0) / slice.length;
      smoothedPoints.push({
        date: active[i].observedAt,
        value: Math.round(avg * 100) / 100,
      });
    }

    // 3. Weekly rate of change (requires at least 7 days and 3 observations)
    const totalDays = (new Date(endDate).getTime() - new Date(startDate).getTime()) / (1000 * 60 * 60 * 24);
    let rateOfChangePerWeek: number | undefined;

    if (totalDays >= 7 && active.length >= 3) {
      rateOfChangePerWeek = Math.round((delta / (totalDays / 7)) * 100) / 100;
    }

    return {
      metricCode,
      count: active.length,
      dataSufficiency: active.length >= 3 && totalDays >= 7 ? 'sufficient' : 'insufficient',
      startDate,
      endDate,
      startValue,
      latestValue,
      delta,
      rateOfChangePerWeek,
      smoothedPoints,
      anomalies,
    };
  }
}
