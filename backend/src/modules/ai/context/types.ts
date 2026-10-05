export type ContextTier = 0 | 1 | 2 | 3 | 4;

export type IntentClass =
  | 'general'
  | 'data_lookup'
  | 'comparison'
  | 'analysis'
  | 'calculation'
  | 'guidance'
  | 'extraction'
  | 'action'
  | 'explanation';

export interface ContextManifest {
  tier: ContextTier;
  intentClass: IntentClass;
  sourceWatermark?: string | undefined;
  includedSections: string[];
  excludedReasons: Record<string, string>;
  recordCount: number;
  dataFreshness: 'fresh' | 'stale' | 'none';
}

export interface SufficiencyResult {
  isSufficient: boolean;
  missingRequirements: string[];
  suggestedAction?: string | undefined;
}

export interface ContextBundle {
  tier: ContextTier;
  intentClass: IntentClass;
  manifest: ContextManifest;
  systemContextText: string;
  isSufficient: boolean;
  insufficiencyReason?: string | undefined;
  snapshot?: any;
}
