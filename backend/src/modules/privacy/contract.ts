/**
 * Privacy Domain Interfaces (ADR-003, §8, §21)
 *
 * Rules:
 * - Every domain module MUST implement the PrivacyContract interface:
 *   1. exportUserData(userId): Export machine-readable data for the user.
 *   2. purgeUserData(userId): Irreversibly delete/erase user data across tables, files, embeddings.
 */

export interface UserDataExport {
  moduleName: string;
  data: Record<string, unknown> | Array<unknown>;
}

export interface PrivacyContract {
  moduleName: string;
  exportUserData(userId: string): Promise<UserDataExport>;
  purgeUserData(userId: string): Promise<{ deletedCount: number }>;
}

export class PrivacyManager {
  private static contracts: Map<string, PrivacyContract> = new Map();

  static register(contract: PrivacyContract): void {
    this.contracts.set(contract.moduleName, contract);
  }

  static async exportAll(userId: string): Promise<Record<string, unknown>> {
    const exported: Record<string, unknown> = {};
    for (const [name, contract] of this.contracts) {
      const res = await contract.exportUserData(userId);
      exported[name] = res.data;
    }
    return exported;
  }

  static async purgeAll(userId: string): Promise<Record<string, number>> {
    const summary: Record<string, number> = {};
    for (const [name, contract] of this.contracts) {
      const res = await contract.purgeUserData(userId);
      summary[name] = res.deletedCount;
    }
    return summary;
  }
}
