import type { TrendAnalysis } from './contracts.js';

export interface DataPoint {
  observedAt: Date;
  value: number;
}

export class TrendEngine {
  /** Minimum observations required before a slope/rate can be trusted. */
  static readonly MIN_TREND_POINTS = 3;
  /** Minimum day-span across points — regression over a narrower window is noise. */
  static readonly MIN_TREND_SPAN_DAYS = 4;
  /** EMA smoothing horizon: 7-day equivalent smoothing for body metrics. */
  static readonly EMA_SPAN_DAYS = 7;
  /** Default reporting window when a caller supplies none. */
  static readonly DEFAULT_WINDOW_DAYS = 30;

  /**
   * Computes noise-robust trend and rate of change for a metric over a defined time window.
   * Invariants:
   * - Requires at least MIN_TREND_POINTS data points spanning at least MIN_TREND_SPAN_DAYS.
   * - Uses an EMA_SPAN_DAYS-day weighted average to filter high-frequency noise.
   * - No silent extrapolation over data voids.
   */
  public static calculateTrend(
    typeCode: string,
    points: DataPoint[],
    windowDays: number = TrendEngine.DEFAULT_WINDOW_DAYS
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

    // Raw series + EMA-smoothed series for client visualization.
    const rawSeries = sorted.map((p) => ({
      observedAt: p.observedAt.toISOString(),
      value: p.value
    }));

    const alpha = 2 / (TrendEngine.EMA_SPAN_DAYS + 1);
    let ema = sorted[0]!.value;
    const smoothedSeries = [{ observedAt: first.observedAt.toISOString(), value: ema }];
    for (let i = 1; i < sorted.length; i++) {
      ema = alpha * sorted[i]!.value + (1 - alpha) * ema;
      smoothedSeries.push({
        observedAt: sorted[i]!.observedAt.toISOString(),
        value: Math.round(ema * 100) / 100
      });
    }

    // Below the minimum point/span bounds, report insufficiency for rate/slope.
    if (count < TrendEngine.MIN_TREND_POINTS || timespanDays < TrendEngine.MIN_TREND_SPAN_DAYS) {
      return {
        typeCode,
        windowDays,
        dataPointCount: count,
        startValue: first.value,
        endValue: last.value,
        deltaValue: Math.round((last.value - first.value) * 100) / 100,
        series: rawSeries,
        smoothedSeries,
        sufficiency: 'insufficient',
        reason: `Insufficient data points (${count}) or timespan (${Math.round(timespanDays)} days). Need at least ${TrendEngine.MIN_TREND_POINTS} points across ${TrendEngine.MIN_TREND_SPAN_DAYS}+ days for a trend rate.`
      };
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
      series: rawSeries,
      smoothedSeries,
      sufficiency: 'complete'
    };
  }
}
