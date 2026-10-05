export interface MetricRollup {
  id: string;
  userId: string;
  measurementTypeCode: string;
  periodType: 'daily' | 'weekly' | 'monthly';
  periodStart: string;
  periodEnd: string;
  count: number;
  meanValue?: number | undefined;
  minValue?: number | undefined;
  maxValue?: number | undefined;
  firstValue?: number | undefined;
  lastValue?: number | undefined;
  sumValue?: number | undefined;
}

export interface TrendAnalysis {
  typeCode: string;
  windowDays: number;
  dataPointCount: number;
  startValue?: number | undefined;
  endValue?: number | undefined;
  deltaValue?: number | undefined;
  weeklyRate?: number | undefined;
  smoothedLatest?: number | undefined;
  slopePerDay?: number | undefined;
  series?: { observedAt: string; value: number }[] | undefined;
  smoothedSeries?: { observedAt: string; value: number }[] | undefined;
  sufficiency: 'complete' | 'insufficient';
  reason?: string | undefined;
}

export interface AnomalyFlag {
  id: string;
  userId: string;
  observationId: string;
  flagType: 'implausible_jump' | 'unit_mismatch_suspect' | 'extreme_outlier';
  severity: 'info' | 'warning' | 'critical';
  details: Record<string, unknown>;
  createdAt: string;
}

export interface SnapshotIdentityLiteSection {
  units: Record<string, string>;
  language: string;
  ageYears?: number | undefined;
  sexForCalculation?: string | undefined;
  heightCm?: number | undefined;
}

export interface SnapshotBodyStatusSection {
  latestWeightKg?: number | undefined;
  observedAt?: string | undefined;
  trend7dKg?: number | undefined;
  weeklyRateKg?: number | undefined;
  bmi?: number | undefined;
  bmiCategory?: string | undefined;
  sufficiency: 'complete' | 'partial' | 'insufficient';
}

export interface SnapshotGoalSection {
  hasActiveGoal: boolean;
  goalType?: string | undefined;
  targetMetricCode?: string | undefined;
  targetValue?: number | undefined;
  startingValue?: number | undefined;
  currentValue?: number | undefined;
  progressPct?: number | undefined;
  projectedTargetDate?: string | undefined;
  isSafeRate?: boolean | undefined;
}

export interface SnapshotEnergySection {
  bmr?: number | undefined;
  tdee?: number | undefined;
  activityLevel?: string | undefined;
  maintenanceCalories?: number | undefined;
  targetCalories?: number | undefined;
  guardrailsTriggered: string[];
  isRefused: boolean;
  sufficiency: 'complete' | 'insufficient';
}

export interface SnapshotRecentMeasurementItem {
  typeCode: string;
  canonicalValue: number;
  canonicalUnit: string;
  observedAt: string;
  epistemicClass: string;
}

export interface SnapshotDataQualitySection {
  totalActiveObservations: number;
  measuredSharePct: number | null; // null when there are no observations to measure
  stalenessDays?: number | undefined;
  hasAnomalies: boolean;
}

export interface HealthSnapshotSections {
  identityLite: SnapshotIdentityLiteSection;
  bodyStatus: SnapshotBodyStatusSection;
  goal: SnapshotGoalSection;
  energy: SnapshotEnergySection;
  activityLevel: { level?: string | undefined; multiplier?: number | undefined };
  recentMeasurements: SnapshotRecentMeasurementItem[];
  anomalies: AnomalyFlag[];
  dataQuality: SnapshotDataQualitySection;
}

export interface HealthSnapshot {
  userId: string;
  snapshotVersion: number;
  sourceDataWatermark: string;
  sections: HealthSnapshotSections;
  reconciledAt: string;
  createdAt: string;
  updatedAt: string;
}
