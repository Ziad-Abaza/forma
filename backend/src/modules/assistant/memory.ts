import { withUserContext } from '../../core/database/index.js';
import type { AssistantMemory, SaveMemoryRequest } from './contracts.js';

export class AssistantMemoryService {
  /**
   * Retrieves active durable memories for a user, optionally filtered by category.
   */
  static async getMemories(userId: string, category?: string): Promise<AssistantMemory[]> {
    return await withUserContext(userId, async (client) => {
      let query = `
        SELECT id, user_id, category, key, value, confidence, source, provenance_id, is_active, created_at, updated_at
        FROM assistant_memories
        WHERE user_id = $1 AND is_active = TRUE
      `;
      const params: any[] = [userId];

      if (category) {
        query += ` AND category = $2`;
        params.push(category);
      }

      query += ` ORDER BY created_at ASC`;

      const result = await client.query(query, params);
      return result.rows.map(mapMemoryRow);
    });
  }

  /**
   * Saves or updates a memory entry with deduplication on (user_id, category, key).
   */
  static async saveMemory(
    userId: string,
    req: SaveMemoryRequest,
    provenanceId?: string,
    source: string = 'assistant_proposal'
  ): Promise<AssistantMemory> {
    const suspiciousPattern = /\b(ignore\s+all\s+previous|system\s+prompt|you\s+are\s+now|developer\s+mode|override\s+instructions)\b/i;
    if (suspiciousPattern.test(req.value)) {
      throw new Error('Instruction-like pattern detected in memory value. Cannot save as memory.');
    }

    return await withUserContext(userId, async (client) => {
      const query = `
        INSERT INTO assistant_memories (user_id, category, key, value, confidence, source, provenance_id, is_active, updated_at)
        VALUES ($1, $2, $3, $4, $5, $6, $7, TRUE, NOW())
        ON CONFLICT (user_id, category, key)
        DO UPDATE SET
          value = EXCLUDED.value,
          confidence = EXCLUDED.confidence,
          source = EXCLUDED.source,
          provenance_id = EXCLUDED.provenance_id,
          is_active = TRUE,
          updated_at = NOW()
        RETURNING id, user_id, category, key, value, confidence, source, provenance_id, is_active, created_at, updated_at
      `;

      const result = await client.query(query, [
        userId,
        req.category,
        req.key,
        req.value,
        req.confidence ?? 1.0,
        source,
        provenanceId || null
      ]);

      return mapMemoryRow(result.rows[0]);
    });
  }

  /**
   * Deactivates (soft deletes) a memory entry by ID.
   */
  static async deleteMemory(userId: string, memoryId: string): Promise<boolean> {
    return await withUserContext(userId, async (client) => {
      const result = await client.query(
        `UPDATE assistant_memories SET is_active = FALSE, updated_at = NOW() WHERE id = $1 AND user_id = $2`,
        [memoryId, userId]
      );
      return (result.rowCount ?? 0) > 0;
    });
  }

  /**
   * Formats durable user memories into a compact text block for system context prompt.
   */
  static async formatMemoriesForContext(userId: string): Promise<string> {
    const memories = await this.getMemories(userId);
    if (memories.length === 0) return 'No known durable preferences or constraints.';

    return memories
      .map((m) => `- [${m.category.toUpperCase()}] ${m.key}: ${m.value}`)
      .join('\n');
  }
}

function mapMemoryRow(row: any): AssistantMemory {
  return {
    id: row.id,
    userId: row.user_id,
    category: row.category,
    key: row.key,
    value: row.value,
    confidence: Number(row.confidence),
    source: row.source,
    provenanceId: row.provenance_id,
    isActive: row.is_active,
    createdAt: row.created_at.toISOString ? row.created_at.toISOString() : String(row.created_at),
    updatedAt: row.updated_at.toISOString ? row.updated_at.toISOString() : String(row.updated_at)
  };
}
