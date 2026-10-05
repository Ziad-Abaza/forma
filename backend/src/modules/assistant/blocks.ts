import { z } from 'zod';

export const MetricTileSchema = z.object({
  label: z.string().min(1).max(50),
  value: z.number(),
  unit: z.string().optional(),
  delta: z.number().optional(),
  period: z.enum(['7d', '30d', '90d']).optional(),
  evidence: z.enum(['retrieved', 'calculated', 'estimated', 'inferred', 'recommended']),
  size: z.enum(['sm', 'wide']).default('sm')
});

export type MetricTile = z.infer<typeof MetricTileSchema>;

export const FormaMetricsSchema = z.object({
  tiles: z.array(MetricTileSchema).min(1).max(4)
});

export type FormaMetricsBlock = z.infer<typeof FormaMetricsSchema>;

export const FormaSuggestionsSchema = z.object({
  items: z.array(z.string().min(1).max(50)).min(1).max(3)
});

export type FormaSuggestionsBlock = z.infer<typeof FormaSuggestionsSchema>;

export interface ExtractedBlocks {
  cleanedText: string;
  metricsBlock?: FormaMetricsBlock | undefined;
  suggestionsBlock?: FormaSuggestionsBlock | undefined;
  formatViolations: number;
}

export class StructuredBlocksExtractor {
  /**
   * Extracts ```forma:metrics and ```forma:suggestions blocks, parses and validates them with Zod,
   * validates metric values against trusted snapshot if provided, and removes them from visible text.
   */
  public static extractAndValidate(
    rawText: string,
    trustedSnapshot?: Record<string, any>
  ): ExtractedBlocks {
    let cleanedText = rawText;
    let formatViolations = 0;
    let metricsBlock: FormaMetricsBlock | undefined;
    let suggestionsBlock: FormaSuggestionsBlock | undefined;

    // 1. Extract forma:metrics
    const metricsRegex = /```forma:metrics\s*([\s\S]*?)\s*```/g;
    const metricsMatches = [...rawText.matchAll(metricsRegex)];

    if (metricsMatches.length > 0) {
      // Limit: at most 1 block per message
      const firstMatch = metricsMatches[0]!;
      try {
        const jsonContent = (firstMatch[1] ?? '').trim();
        const parsedJson = JSON.parse(jsonContent);
        const validated = FormaMetricsSchema.safeParse(parsedJson);
        if (validated.success) {
          // G-A2: Validate retrieved and calculated values against trusted snapshot
          const validTiles: MetricTile[] = [];
          for (const tile of validated.data.tiles) {
            if (tile.evidence === 'retrieved' || tile.evidence === 'calculated') {
              if (this.isMetricGroundedInSnapshot(tile, trustedSnapshot)) {
                validTiles.push(tile);
              } else {
                formatViolations++; // Dropped forged/ungrounded tile
              }
            } else {
              validTiles.push(tile);
            }
          }

          if (validTiles.length > 0) {
            metricsBlock = { tiles: validTiles.slice(0, 4) };
          }
        } else {
          formatViolations++;
        }
      } catch {
        formatViolations++;
      }

      // Remove all metrics blocks from visible markdown text
      cleanedText = cleanedText.replace(metricsRegex, '');
    }

    // 2. Extract forma:suggestions
    const suggestionsRegex = /```forma:suggestions\s*([\s\S]*?)\s*```/g;
    const suggestionsMatches = [...rawText.matchAll(suggestionsRegex)];

    if (suggestionsMatches.length > 0) {
      const firstMatch = suggestionsMatches[0]!;
      try {
        const jsonContent = (firstMatch[1] ?? '').trim();
        const parsedJson = JSON.parse(jsonContent);
        const validated = FormaSuggestionsSchema.safeParse(parsedJson);
        if (validated.success) {
          suggestionsBlock = {
            items: validated.data.items.slice(0, 3).map((item) => item.trim())
          };
        } else {
          formatViolations++;
        }
      } catch {
        formatViolations++;
      }

      // Remove all suggestions blocks from visible markdown text
      cleanedText = cleanedText.replace(suggestionsRegex, '');
    }

    return {
      cleanedText: cleanedText.trim(),
      metricsBlock,
      suggestionsBlock,
      formatViolations
    };
  }

  /**
   * Validates whether a tile's numeric value matches a known value in the snapshot within ±0.5% (Spec §4.2 G-A2).
   */
  private static isMetricGroundedInSnapshot(
    tile: MetricTile,
    snapshot?: Record<string, any>
  ): boolean {
    if (!snapshot) return true; // If no snapshot passed, cannot reject

    const numericVal = tile.value;
    const knownValues: number[] = [];

    // Helper to traverse snapshot recursively and extract numbers
    const extractNumbers = (obj: any) => {
      if (!obj || typeof obj !== 'object') return;
      for (const val of Object.values(obj)) {
        if (typeof val === 'number') {
          knownValues.push(val);
        } else if (typeof val === 'object') {
          extractNumbers(val);
        }
      }
    };

    extractNumbers(snapshot);

    if (knownValues.length === 0) return true;

    // Check if numericVal is within 0.5% of any known number or within 0.1 difference
    return knownValues.some((k) => {
      const tolerance = Math.max(0.1, Math.abs(k) * 0.005);
      return Math.abs(k - numericVal) <= tolerance;
    });
  }
}
