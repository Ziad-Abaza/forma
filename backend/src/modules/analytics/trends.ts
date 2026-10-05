import type { TrendAnalysis } from './contracts.js';

export interface DataPoint {
  observedAt: Date;
  value: number;
}

export class TrendEngine {
  /**
   * Computes noise-robust trend and rate of change for a metric over a defined time window.
   * Invariants:
   * - Requires at least 3 data points spanning at least 4 days for slope estimation.
   * - Uses a 7-day rolling window / weighted average to filter high-frequency noise.
   * - No silent extrapolation over data voids.
   */
  public static calculateTrend(
    typeCode: string,
    points: DataPoint[],
    windowDays: number = 30
  ): TrendAnalysis {
    if (!points || points.length === 0) {
      return {
        typeCode,
        windowDays,
        dataPointCount: 0,
        sufficiency: 'insufficient',
        reason: 'No data points recorded in this window.'
      };
    }

    // Sort chronologically ascending
    const sorted = [...points].sort((a, b) => a.observedAt.getTime() - b.observedAt.getTime());
    const count = sorted.length;

    const first = sorted[0]!;
    const last = sorted[sorted.length - 1]!;
    const timespanMs = last.observedAt.getTime() - first.observedAt.getTime();
    const timespanDays = timespanMs / (1000 * 60 * 60 * 24);

    // If fewer than 3 points or spanning less than 4 days, report insufficiency for rate/slope
    if (count < 3 || timespanDays < 4) {
      return {
        typeCode,
        windowDays,
        dataPointCount: count,
        startValue: first.value,
        endValue: last.value,
        deltaValue: Math.round((last.value - first.value) * 100) / 100,
        sufficiency: 'insufficient',
        reason: `Insufficient data points (${count}) or timespan (${Math.round(timespanDays)} days). Need at least 3 points across 4+ days for a trend rate.`
      };
    }

    // Exponential Moving Average (EMA) for noise filtering
    // alpha = 2 / (N + 1), where N = 7 (7-day smoothing)
    const alpha = 2 / (7 + 1);
    let ema = sorted[0]!.value;
    for (let i = 1; i < sorted.length; i++) {
      ema = alpha * sorted[i]!.value + (1 - alpha) * ema;
    }
    const smoothedLatest = Math.round(ema * 100) / 100;

    // Linear regression (ordinary least squares) to find robust daily slope
    // x = days from first point, y = value
    let sumX = 0;
    let sumY = 0;
    let sumXY = 0;
    let sumXX = 0;

    for (const pt of sorted) {
      const x = (pt.observedAt.getTime() - first.observedAt.getTime()) / (1000 * 60 * 60 * 24);
      const y = pt.value;
      sumX += x;
      sumY += y;
      sumXY += x * y;
      sumXX += x * x;
    }

    const n = count;
    const denominator = n * sumXX - sumX * sumX;
    let slopePerDay = 0;

    if (denominator !== 0) {
      slopePerDay = (n * sumXY - sumX * sumY) / denominator;
    }

    const weeklyRate = Math.round(slopePerDay * 7 * 100) / 100;
    const deltaValue = Math.round((last.value - first.value) * 100) / 100;

    return {
      typeCode,
      windowDays,
      dataPointCount: count,
      startValue: first.value,
      endValue: last.value,
      deltaValue,
      weeklyRate,
      smoothedLatest,
      slopePerDay: Math.round(slopePerDay * 1000) / 1000,
      sufficiency: 'complete'
    };
  }
}
