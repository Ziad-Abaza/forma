import { ContextBundle, ContextManifest } from './types.js';
import { ContextPlanner } from './planner.js';

export interface ContextEngineServices {
  snapshotService: any;
  measurementsService?: any;
  goalsService?: any;
}

export class AIContextEngine {
  constructor(private readonly services: ContextEngineServices) {}

  public async assembleContext(userId: string, userPrompt: string): Promise<ContextBundle> {
    const plan = ContextPlanner.planIntentAndTier(userPrompt);

    // Tier 0: No user data supplied
    if (plan.tier === 0) {
      const manifest: ContextManifest = {
        tier: 0,
        intentClass: plan.intent,
        includedSections: [],
        excludedReasons: {
          userData: 'Tier 0 General Query does not permit user health context',
        },
        recordCount: 0,
        dataFreshness: 'none',
      };

      return {
        tier: 0,
        intentClass: plan.intent,
        manifest,
        systemContextText: 'This is a general educational query. Answer using vetted fitness and nutrition principles without referencing any user-specific health data.',
        isSufficient: true,
      };
    }

    // Tier 1+: Retrieve Health Snapshot
    const snapshot = this.services.snapshotService.getOrRefreshSnapshot
      ? await this.services.snapshotService.getOrRefreshSnapshot(userId)
      : await this.services.snapshotService.getSnapshot(userId);

    const sections: any = snapshot.sections;
    const bodySec = sections.bodyStatus || sections.body_status;
    const hasWeight = bodySec && bodySec.latestWeightKg !== undefined && bodySec.latestWeightKg !== null;

    if (!hasWeight && (plan.intent === 'data_lookup' || plan.intent === 'comparison')) {
      const manifest: ContextManifest = {
        tier: plan.tier,
        intentClass: plan.intent,
        includedSections: [],
        excludedReasons: {
          snapshot: 'User has no recorded weight observations yet',
        },
        recordCount: 0,
        dataFreshness: 'none',
      };

      return {
        tier: plan.tier,
        intentClass: plan.intent,
        manifest,
        systemContextText: '',
        isSufficient: false,
        insufficiencyReason: 'I do not have enough information to answer this yet. Please log your first body measurement (e.g. weight) in the app to establish your baseline.',
      };
    }

    // Assemble compact, provenance-labeled Tier 1 context text
    const includedSections: string[] = [];
    const asOfStr = snapshot.reconciledAt || snapshot.updatedAt || new Date().toISOString();
    const contextLines: string[] = [
      `### Verified User Health Snapshot (As Of: ${asOfStr})`,
      `[Source Watermark: ${snapshot.sourceDataWatermark || 'N/A'}]`,
    ];

    const identitySec = sections.identityLite || sections.overview;
    if (identitySec) {
      includedSections.push('identityLite');
      contextLines.push(
        `- Profile [Measured/Asserted]: Height: ${identitySec.heightCm || 'unknown'} cm, Age: ${identitySec.ageYears || 'unknown'}, Sex: ${identitySec.sexForCalculation || identitySec.sex || 'unknown'}`
      );
    }

    if (bodySec) {
      includedSections.push('bodyStatus');
      contextLines.push(
        `- Latest Weight [Measured]: ${bodySec.latestWeightKg ?? 'unknown'} kg`
      );
      if (bodySec.bmi || bodySec.latestBmi) {
        contextLines.push(
          `- BMI [Calculated]: ${bodySec.bmi || bodySec.latestBmi} (${bodySec.bmiCategory || 'unknown'})`
        );
      }
    }

    if (sections.energy) {
      includedSections.push('energy');
      contextLines.push(
        `- Energy Targets [Calculated]: Maintenance: ${sections.energy.maintenanceCalories ?? 'unknown'} kcal, Target: ${sections.energy.targetCalories ?? 'unknown'} kcal`
      );
    }

    const goalSec = sections.goal || sections.goals;
    if (goalSec && goalSec.hasActiveGoal) {
      includedSections.push('goal');
      contextLines.push(
        `- Primary Goal [Asserted]: ${goalSec.goalType || goalSec.primaryGoalCategory || 'none'}, Target: ${goalSec.targetValue ?? 'unknown'}`
      );
    }

    const trendSec = sections.trends || sections.bodyStatus;
    if (trendSec && (trendSec.weeklyRateKg !== undefined || trendSec.weeklyRate !== undefined)) {
      includedSections.push('trends');
      const rate = trendSec.weeklyRateKg ?? trendSec.weeklyRate;
      contextLines.push(
        `- Weight Trend (7d EMA) [Calculated]: ${rate !== undefined ? rate + ' kg/wk' : 'insufficient data points'}`
      );
    }

    const manifest: ContextManifest = {
      tier: plan.tier,
      intentClass: plan.intent,
      sourceWatermark: snapshot.sourceDataWatermark,
      includedSections,
      excludedReasons: {
        rawDatabase: 'Raw observations excluded; compacted snapshot provided under Context Minimization',
      },
      recordCount: includedSections.length,
      dataFreshness: snapshot.sourceDataWatermark ? 'fresh' : 'stale',
    };

    return {
      tier: plan.tier,
      intentClass: plan.intent,
      manifest,
      systemContextText: contextLines.join('\n'),
      isSufficient: true,
    };
  }
}
