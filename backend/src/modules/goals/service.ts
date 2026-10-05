import { GoalsRepository } from './repository.js';
import { computeGoalProgressPct, type CreateGoalRequest, type UpdateGoalVersionRequest, type Goal, type GoalVersion } from './contracts.js';
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

  public async listGoalVersions(userId: string, goalId: string): Promise<GoalVersion[]> {
    return this.repo.listGoalVersions(userId, goalId);
  }

  public async exportData(userId: string): Promise<Record<string, unknown>> {
    return this.repo.exportUserData(userId);
  }

  public async purgeData(userId: string): Promise<void> {
    return this.repo.purgeUserData(userId);
  }

  public async updateGoalStatus(userId: string, goalId: string, status: string): Promise<boolean> {
    return this.repo.updateGoalStatus(userId, goalId, status);
  }

  private async enrichGoalWithProgress(userId: string, goal: Goal): Promise<Goal> {
    if (!goal.currentVersion) return goal;

    // Get latest active measurement for this target metric
    const latestObs = await MeasurementsService.getLatestObservation(
      userId,
      goal.targetMetricTypeCode
    );

    // No real measurement of the goal's metric → progress is unknown, not 0
    // at a fabricated "starting value" reading.
    if (!latestObs) return goal;

    const currentVal = Number(latestObs.canonical_value);
    const startVal = goal.currentVersion.startingValue;
    const targetVal = goal.currentVersion.targetValue;

    return {
      ...goal,
      currentValue: currentVal,
      progressPct: computeGoalProgressPct(goal.goalType, startVal, targetVal, currentVal)
    };
  }
}
