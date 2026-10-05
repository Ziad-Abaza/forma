import type { AnomalyFlag } from './contracts.js';

export interface ObservationCheckItem {
  id: string;
  typeCode: string;
  canonicalValue: number;
  observedAt: Date;
}

export class AnomalyDetector {
  /**
   * Checks a newly recorded or existing observation against history for anomalies.
   * Never mutates or deletes the observation. Only returns warning flags.
   */
  public static checkObservation(
    userId: string,
    current: ObservationCheckItem,
    recentHistory: ObservationCheckItem[]
  ): AnomalyFlag | null {
    if (current.typeCode === 'weight') {
      // 1. Check for unit mismatch suspect (e.g. entered lbs in a kg field: > 160 kg when prior was < 90 kg)
      const priorObservations = recentHistory
        .filter((h) => h.observedAt.getTime() <= current.observedAt.getTime())
        .sort((a, b) => b.observedAt.getTime() - a.observedAt.getTime());

      if (priorObservations.length > 0) {
        const last = priorObservations[0]!;
        const timeDiffHours = Math.abs(current.observedAt.getTime() - last.observedAt.getTime()) / (1000 * 60 * 60);

        // If weight jumped by > 3.0 kg in under 24 hours
        if (timeDiffHours <= 24 && Math.abs(current.canonicalValue - last.canonicalValue) > 3.0) {
          // Check if current value looks like it was entered in lbs:
          // current / 2.20462 ~= last
          const suspectedKg = current.canonicalValue / 2.20462;
          const isSuspectedLbs = Math.abs(suspectedKg - last.canonicalValue) < 2.5;

          if (isSuspectedLbs) {
            return {
              id: `flag-${current.id}`,
              userId,
              observationId: current.id,
              flagType: 'unit_mismatch_suspect',
              severity: 'warning',
              details: {
                previousWeightKg: last.canonicalValue,
                currentWeightKg: current.canonicalValue,
                suspectedUnitMismatch: 'Entered lbs instead of kg',
                suggestedValue: Math.round(suspectedKg * 10) / 10
              },
              createdAt: new Date().toISOString()
            };
          }

          return {
            id: `flag-${current.id}`,
            userId,
            observationId: current.id,
            flagType: 'implausible_jump',
            severity: 'warning',
            details: {
              previousWeightKg: last.canonicalValue,
              currentWeightKg: current.canonicalValue,
              deltaKg: Math.round((current.canonicalValue - last.canonicalValue) * 10) / 10,
              hoursApart: Math.round(timeDiffHours * 10) / 10
            },
            createdAt: new Date().toISOString()
          };
        }
      }
    }

    return null;
  }
}
