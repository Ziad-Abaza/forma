/**
 * Dashboard Domain (ADR-003, §8, §18.1)
 *
 * Rules:
 * - Widget composition contract: ranked list of widgets declaring domain,
 *   freshness, empty states, and priority signals.
 * - Future domains add widgets without altering the dashboard core.
 * - No widget requires a live AI call to render.
 * - Widgets read the same Health Snapshot & aggregates the assistant uses.
 */

import { HealthSnapshot } from '../analytics/snapshot.js';

export type WidgetType =
  | 'status_goal'
  | 'recent_measurements'
  | 'trends'
  | 'targets'
  | 'anomalies_alert';

export interface DashboardWidget<T = unknown> {
  id: string;
  type: WidgetType;
  title: { en: string; ar: string };
  priority: number;
  isEmpty: boolean;
  emptyStateMessage?: { en: string; ar: string };
  data?: T;
  asOf: string;
}

export class DashboardService {
  /**
   * Compose dashboard widgets deterministically from the user's Health Snapshot.
   */
  static composeDashboard(snapshot: HealthSnapshot): DashboardWidget[] {
    const widgets: DashboardWidget[] = [];
    const asOf = snapshot.generatedAt;

    // 1. Status & Goal Widget
    const goalData = snapshot.sections.primaryGoal?.data;
    widgets.push({
      id: 'w_status_goal',
      type: 'status_goal',
      title: { en: 'Goal Progress', ar: 'التقدم نحو الهدف' },
      priority: 10,
      isEmpty: !goalData,
      emptyStateMessage: {
        en: 'No active primary goal set. Choose a target to track progress.',
        ar: 'لا يوجد هدف رئيسي نشط. حدد هدفاً لمتابعة تقدمك.',
      },
      data: goalData,
      asOf,
    });

    // 2. Targets & Energy Widget
    const energyData = snapshot.sections.energy.data;
    widgets.push({
      id: 'w_targets',
      type: 'targets',
      title: { en: 'Daily Energy & Macros', ar: 'الطاقة والعناصر الغذائية اليومية' },
      priority: 8,
      isEmpty: energyData.tdeeKcal === 0,
      emptyStateMessage: {
        en: 'Log weight and profile to calculate calorie targets.',
        ar: 'سجل وزنك وملفك الشخصي لحساب أهداف السعرات الحرارية.',
      },
      data: energyData,
      asOf,
    });

    // 3. Body Status / Trends Widget
    const bodyData = snapshot.sections.bodyStatus.data;
    widgets.push({
      id: 'w_trends',
      type: 'trends',
      title: { en: 'Body Trends', ar: 'مؤشرات الجسم' },
      priority: 7,
      isEmpty: !bodyData.latestWeightKg,
      emptyStateMessage: {
        en: 'Log your first weight observation to see trends.',
        ar: 'سجل قراءة وزنك الأولى لعرض الرسوم البيانية.',
      },
      data: bodyData,
      asOf,
    });

    // 4. Anomalies / Quality Alert (High priority if present)
    const anomalies = snapshot.sections.anomalies.data;
    if (anomalies && anomalies.length > 0) {
      widgets.unshift({
        id: 'w_anomalies',
        type: 'anomalies_alert',
        title: { en: 'Measurement Notice', ar: 'تنبيه القياسات' },
        priority: 100, // Top priority
        isEmpty: false,
        data: anomalies,
        asOf,
      });
    }

    return widgets.sort((a, b) => b.priority - a.priority);
  }
}
