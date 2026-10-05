import { GoalsRepository } from './repository.js';
import type { CreateGoalRequest, UpdateGoalVersionRequest, Goal } from './contracts.js';
import type { ExportableModule, DeletableModule } from '../privacy/index.js';
import { MeasurementsService } from '../measurements/service.js';

export class GoalsService implements ExportableModule, DeletableModule {
  public readonly moduleName = 'goals';

  constructor(
    private readonly repo = new GoalsRepository()
  ) {}

  public async createGoal(userId: string, data: CreateGoalRequest): Promise<Goal> {
    const goal = await this.repo.createGoal(userId, data);
    return this.enrichGoalWithProgress(userId, goal);
  }

  public async addGoalVersion(
    userId: string,
    goalId: string,
    data: UpdateGoalVersionRequest
  ): Promise<Goal> {
    await this.repo.addGoalVersion(userId, goalId, data);
    const goals = await this.repo.listGoals(userId);
    const updated = goals.find((g) => g.id === goalId);
    if (!updated) throw new Error('Goal not found after update');
    return this.enrichGoalWithProgress(userId, updated);
  }

  public async getPrimaryGoal(userId: string): Promise<Goal | null> {
    const goal = await this.repo.getPrimaryGoal(userId);
    if (!goal) return null;
    return this.enrichGoalWithProgress(userId, goal);
  }

  public async listGoals(userId: string): Promise<Goal[]> {
    const goals = await this.repo.listGoals(userId);
    return Promise.all(goals.map((g) => this.enrichGoalWithProgress(userId, g)));
  }

  public async exportData(userId: string): Promise<Record<string, unknown>> {
    return this.repo.exportUserData(userId);
  }

  public async purgeData(userId: string): Promise<void> {
    return this.repo.purgeUserData(userId);
  }

  private async enrichGoalWithProgress(userId: string, goal: Goal): Promise<Goal> {
    if (!goal.currentVersion) return goal;

    // Get latest active measurement for this target metric
    const latestObs = await MeasurementsService.getLatestObservation(
      userId,
      goal.targetMetricTypeCode
    );

    if (!latestObs) {
      return {
        ...goal,
        currentValue: goal.currentVersion.startingValue,
        progressPct: 0
      };
    }

    const currentVal = Number(latestObs.canonical_value);
    const startVal = goal.currentVersion.startingValue;
    const targetVal = goal.currentVersion.targetValue;

    let progressPct = 0;
    const totalDistance = Math.abs(targetVal - startVal);

    if (totalDistance === 0) {
      progressPct = 100;
    } else if (goal.goalType === 'weight_loss' || targetVal < startVal) {
      // Moving down
      const distanceCovered = startVal - currentVal;
      progressPct = Math.round((distanceCovered / totalDistance) * 1000) / 10;
    } else {
      // Moving up
      const distanceCovered = currentVal - startVal;
      progressPct = Math.round((distanceCovered / totalDistance) * 1000) / 10;
    }

    return {
      ...goal,
      currentValue: currentVal,
      progressPct
    };
  }
}
