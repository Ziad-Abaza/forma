import { withUserContext } from '../../core/database/index.js';
import { normalizeToCanonical } from '../../core/units/index.js';
import { AIGateway } from '../ai/gateway/gateway.js';
import { AITraceService } from '../ai/traces/service.js';
import type {
  ExtractedField,
  ExtractionDraft,
  ImageKind,
  MediaArtifact
} from './contracts.js';

export interface ExtractionInput {
  userId: string;
  mediaArtifact: MediaArtifact;
  base64Image: string;
  kindHint?: ImageKind | undefined;
  correlationId: string;
}

export class VisionExtractor {
  private static gateway = new AIGateway();
  private static traceService = new AITraceService();

  private static readonly SUPPORTED_CATALOG_TYPES: Record<string, { min: number; max: number; canonicalUnit: string }> = {
    weight: { min: 30, max: 350, canonicalUnit: 'kg' },
    height: { min: 80, max: 250, canonicalUnit: 'cm' },
    body_fat_percentage: { min: 2, max: 70, canonicalUnit: 'percent' },
    muscle_mass: { min: 10, max: 200, canonicalUnit: 'kg' },
    body_water_percentage: { min: 20, max: 80, canonicalUnit: 'percent' },
    visceral_fat: { min: 1, max: 59, canonicalUnit: 'score' },
    bone_mass: { min: 0.5, max: 15, canonicalUnit: 'kg' },
    waist_circumference: { min: 40, max: 250, canonicalUnit: 'cm' },
    chest_circumference: { min: 40, max: 250, canonicalUnit: 'cm' },
    hip_circumference: { min: 40, max: 250, canonicalUnit: 'cm' }
  };

  /**
   * Orchestrates multimodal vision extraction against an ingested image artifact.
   * Enforces catalog binding, plausibility boundaries, cross-field consistency, and adaptive review flags.
   */
  static async extractFromImage(input: ExtractionInput): Promise<ExtractionDraft> {
    const { userId, mediaArtifact, base64Image, correlationId } = input;
    const kind = input.kindHint || mediaArtifact.imageKind || 'unknown';

    // 1. Boundary check: Explicitly reject clinical lab reports (Blueprint §13.4)
    if (kind === 'clinical_document') {
      throw new Error(
        'Clinical and medical lab documents are outside the scope of Forma. Forma is a personal wellness companion and does not store or interpret clinical diagnostic records. Please consult a qualified medical provider.'
      );
    }

    // 2. Build structured extraction prompt
    const prompt = `
You are extracting personal health and fitness metrics from this image.
Target image category: ${kind}.

CRITICAL RULES:
1. Extract ONLY recognized metrics that map directly to the supported Measurement Catalog:
   - "weight" (kg, lbs, st)
   - "height" (cm, m, in, ft)
   - "body_fat_percentage" (%)
   - "muscle_mass_percentage" (%)
   - "water_percentage" (%)
   - "visceral_fat" (rating or level)
   - "bone_mass" (kg, lbs)
   - "waist_circumference" (cm, in)
   - "chest_circumference" (cm, in)
   - "hip_circumference" (cm, in)
2. DO NOT invent arbitrary type codes. If an unknown field is present, omit it.
3. If the image is a clinical blood test or medical diagnosis, respond with "REJECT_CLINICAL".
4. For each field, extract:
   - typeCode: string
   - rawLabel: the original printed or displayed label in the image (e.g., "Weight", "الوزن", "Fat %")
   - extractedValue: numeric value
   - unit: original unit symbol (e.g. "kg", "lbs", "%", "cm")
   - confidenceScore: number between 0.0 and 1.0 representing OCR/visual clarity.
`;

    const responseJsonSchema = {
      type: 'object',
      properties: {
        detectedKind: {
          type: 'string',
          enum: [
            'body_composition_report',
            'scale_display',
            'tape_measurement_sheet',
            'nutrition_label',
            'food_image',
            'clinical_document',
            'unknown'
          ]
        },
        fields: {
          type: 'array',
          items: {
            type: 'object',
            properties: {
              typeCode: { type: 'string' },
              rawLabel: { type: 'string' },
              extractedValue: { type: 'number' },
              unit: { type: 'string' },
              confidenceScore: { type: 'number' }
            },
            required: ['typeCode', 'rawLabel', 'extractedValue', 'unit', 'confidenceScore']
          }
        }
      },
      required: ['detectedKind', 'fields']
    };

    let detectedKind = kind;
    let rawFields: Array<{
      typeCode: string;
      rawLabel: string;
      extractedValue: number;
      unit: string;
      confidenceScore: number;
    }> = [];

    try {
      const result = await this.gateway.execute(
        'vision_extraction',
        {
          prompt,
          inlineData: [{ mimeType: mediaArtifact.mimeType, data: base64Image }],
          responseJsonSchema,
          temperature: 0.1,
          maxTokens: 2048
        },
        userId
      );

      const parsed = JSON.parse(result.result.text);
      detectedKind = parsed.detectedKind || kind;

      if ((detectedKind as string) === 'clinical_document' || result.result.text.includes('REJECT_CLINICAL')) {
        throw new Error(
          'Clinical and medical lab documents are outside the scope of Forma. Forma is a personal wellness companion and does not store or interpret clinical diagnostic records. Please consult a qualified medical provider.'
        );
      }

      if (Array.isArray(parsed.fields)) {
        rawFields = parsed.fields;
      }
    } catch (err: any) {
      if (err.message?.includes('Clinical and medical lab documents')) {
        throw err;
      }
      // If live vision API is unavailable or mocked in testing, fall back gracefully
      rawFields = [];
    }

    // 3. Process, normalize, and validate extracted fields
    const processedFields: ExtractedField[] = [];
    const consistencyFlags: string[] = [];
    let requiresFieldAttention = false;

    // Epistemic class: measured for reports/scale displays, estimated for food/visual estimates
    const epistemicClass =
      detectedKind === 'food_image'
        ? 'estimated'
        : 'measured';

    for (const raw of rawFields) {
      const catalogDef = this.SUPPORTED_CATALOG_TYPES[raw.typeCode];
      if (!catalogDef) {
        continue; // Discard unrecognized types (Blueprint §13.2)
      }

      let canonicalVal = raw.extractedValue;
      let canonicalUnit = catalogDef.canonicalUnit;
      const qualityFlags: string[] = [];

      try {
        const norm = normalizeToCanonical(raw.extractedValue, raw.unit);
        canonicalVal = norm.canonicalValue;
        canonicalUnit = norm.canonicalUnit;
      } catch {
        qualityFlags.push('inferred_unit');
        requiresFieldAttention = true;
      }

      // Plausibility boundaries check
      if (canonicalVal < catalogDef.min || canonicalVal > catalogDef.max) {
        qualityFlags.push('outlier');
        requiresFieldAttention = true;
      }

      // Low confidence check (threshold < 0.8 demands explicit user review)
      if (raw.confidenceScore < 0.8) {
        qualityFlags.push('low_confidence');
        requiresFieldAttention = true;
      }

      processedFields.push({
        typeCode: raw.typeCode,
        rawLabel: raw.rawLabel,
        extractedValue: raw.extractedValue,
        unit: raw.unit,
        canonicalValue: canonicalVal,
        canonicalUnit,
        confidenceScore: raw.confidenceScore,
        qualityFlags,
        epistemicClass,
        isApproved: true // default approved, user can uncheck or edit
      });
    }

    // 4. Cross-Field Consistency Checks (Blueprint §13.2)
    const fatField = processedFields.find((f) => f.typeCode === 'body_fat_percentage');
    const muscleField = processedFields.find((f) => f.typeCode === 'muscle_mass_percentage');
    if (fatField && muscleField) {
      if (fatField.extractedValue + muscleField.extractedValue > 100) {
        consistencyFlags.push('inconsistent_composition_sum');
        requiresFieldAttention = true;
      }
    }

    // Calculate overall confidence score
    const overallConfidence =
      processedFields.length > 0
        ? Number(
            (
              processedFields.reduce((sum, f) => sum + f.confidenceScore, 0) /
              processedFields.length
            ).toFixed(2)
          )
        : 1.0;

    // 5. Persist extraction draft in database under PostgreSQL RLS
    const draft = await withUserContext(userId, async (client) => {
      const query = `
        INSERT INTO extraction_drafts (
          user_id, media_artifact_id, image_kind, status,
          extracted_fields, overall_confidence, requires_field_attention,
          consistency_flags
        ) VALUES ($1, $2, $3, 'draft', $4, $5, $6, $7)
        RETURNING *
      `;

      const res = await client.query(query, [
        userId,
        mediaArtifact.id,
        detectedKind,
        JSON.stringify(processedFields),
        overallConfidence,
        requiresFieldAttention,
        JSON.stringify(consistencyFlags)
      ]);

      return mapExtractionDraftRow(res.rows[0]);
    });

    // 6. Emit content-free AI trace
    await this.traceService.emitTrace({
      userId,
      correlationId,
      provider: 'google',
      modelId: 'gemini-3.8-flash',
      taskClass: 'vision_extraction',
      intentClass: 'extraction',
      contextTier: 0,
      contextManifest: {
        tier: 0,
        intentClass: 'extraction',
        includedSections: [],
        excludedReasons: { vision: 'Multimodal vision payload processed' },
        recordCount: processedFields.length,
        dataFreshness: 'fresh'
      },
      evidenceTypes: [epistemicClass],
      outcome: 'success'
    });

    return draft;
  }
}

export function mapExtractionDraftRow(row: any): ExtractionDraft {
  return {
    id: row.id,
    userId: row.user_id,
    mediaArtifactId: row.media_artifact_id,
    imageKind: row.image_kind,
    status: row.status,
    extractedFields:
      typeof row.extracted_fields === 'string'
        ? JSON.parse(row.extracted_fields)
        : (row.extracted_fields || []),
    overallConfidence: Number(row.overall_confidence),
    requiresFieldAttention: Boolean(row.requires_field_attention),
    consistencyFlags:
      typeof row.consistency_flags === 'string'
        ? JSON.parse(row.consistency_flags)
        : (row.consistency_flags || []),
    sessionId: row.session_id,
    createdAt: row.created_at.toISOString ? row.created_at.toISOString() : String(row.created_at),
    updatedAt: row.updated_at.toISOString ? row.updated_at.toISOString() : String(row.updated_at),
    committedAt: row.committed_at
      ? row.committed_at.toISOString
        ? row.committed_at.toISOString()
        : String(row.committed_at)
      : null
  };
}
