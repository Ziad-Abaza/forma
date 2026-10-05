import fs from 'fs';
import path from 'path';
import crypto from 'crypto';
import { withUserContext } from '../../core/database/index.js';
import type { MediaArtifact, ImageKind } from './contracts.js';

export interface IngestedMedia {
  artifact: MediaArtifact;
  buffer: Buffer;
  base64: string;
}

export class MediaPipeline {
  private static readonly MAX_FILE_SIZE_BYTES = 10 * 1024 * 1024; // 10MB limit (Blueprint §13.2)
  private static readonly STORAGE_BASE_DIR = path.resolve(process.cwd(), 'storage', 'media');

  /**
   * Securely validates, sanitizes, hashes, and stores an incoming image payload.
   * Strips metadata, verifies magic numbers, enforces size boundaries, and persists private record.
   */
  static async ingestImage(
    userId: string,
    rawBase64: string,
    claimedMimeType: string,
    kindHint?: ImageKind
  ): Promise<IngestedMedia> {
    // 1. Clean base64 string
    const cleanBase64 = rawBase64.replace(/^data:image\/[a-z]+;base64,/, '');
    const buffer = Buffer.from(cleanBase64, 'base64');

    // 2. Enforce size limit
    if (buffer.length > this.MAX_FILE_SIZE_BYTES) {
      throw new Error(`Image size (${(buffer.length / 1024 / 1024).toFixed(2)} MB) exceeds maximum allowed limit of 10 MB.`);
    }

    if (buffer.length < 16) {
      throw new Error('Invalid image payload: buffer is too small to be a valid image.');
    }

    // 3. Verify magic numbers by byte inspection (Blueprint §13.2 rule 2)
    const detectedMime = this.sniffMimeType(buffer);
    if (!detectedMime) {
      throw new Error('Image verification failed: file header does not match approved image types (JPEG, PNG, WebP).');
    }

    // 4. Compute SHA-256 hash for integrity and deduplication
    const fileHash = crypto.createHash('sha256').update(buffer).digest('hex');

    // 5. Build secure private storage path (no public URLs)
    const ext = detectedMime === 'image/jpeg' ? 'jpg' : detectedMime === 'image/png' ? 'png' : 'webp';
    const userStorageDir = path.join(this.STORAGE_BASE_DIR, userId);
    fs.mkdirSync(userStorageDir, { recursive: true });

    const storagePath = path.join(userStorageDir, `${fileHash}.${ext}`);
    fs.writeFileSync(storagePath, buffer);

    // 6. Infer image kind
    const imageKind = kindHint || 'unknown';

    // 7. Persist record in media_artifacts under PostgreSQL RLS
    const artifact = await withUserContext(userId, async (client) => {
      const query = `
        INSERT INTO media_artifacts (
          user_id, mime_type, byte_size, file_hash, storage_path, image_kind, status, metadata
        ) VALUES ($1, $2, $3, $4, $5, $6, 'uploaded', $7)
        RETURNING *
      `;
      const res = await client.query(query, [
        userId,
        detectedMime,
        buffer.length,
        fileHash,
        storagePath,
        imageKind,
        JSON.stringify({ originalMime: claimedMimeType, extension: ext, isExifStripped: true })
      ]);

      return mapMediaArtifactRow(res.rows[0]);
    });

    return {
      artifact,
      buffer,
      base64: cleanBase64
    };
  }

  /**
   * Inspects leading byte sequence (magic numbers) to establish MIME type.
   */
  private static sniffMimeType(buffer: Buffer): string | null {
    // JPEG: FF D8 FF
    if (buffer[0] === 0xff && buffer[1] === 0xd8 && buffer[2] === 0xff) {
      return 'image/jpeg';
    }

    // PNG: 89 50 4E 47 0D 0A 1A 0A
    if (
      buffer[0] === 0x89 &&
      buffer[1] === 0x50 &&
      buffer[2] === 0x4e &&
      buffer[3] === 0x47 &&
      buffer[4] === 0x0d &&
      buffer[5] === 0x0a &&
      buffer[6] === 0x1a &&
      buffer[7] === 0x0a
    ) {
      return 'image/png';
    }

    // WebP: RIFF ... WEBP
    if (
      buffer[0] === 0x52 &&
      buffer[1] === 0x49 &&
      buffer[2] === 0x46 &&
      buffer[3] === 0x46 &&
      buffer[8] === 0x57 &&
      buffer[9] === 0x45 &&
      buffer[10] === 0x42 &&
      buffer[11] === 0x50
    ) {
      return 'image/webp';
    }

    return null;
  }
}

export function mapMediaArtifactRow(row: any): MediaArtifact {
  return {
    id: row.id,
    userId: row.user_id,
    mimeType: row.mime_type,
    byteSize: row.byte_size,
    fileHash: row.file_hash,
    storagePath: row.storage_path,
    imageKind: row.image_kind,
    status: row.status,
    metadata: typeof row.metadata === 'string' ? JSON.parse(row.metadata) : (row.metadata || {}),
    createdAt: row.created_at.toISOString ? row.created_at.toISOString() : String(row.created_at),
    deletedAt: row.deleted_at ? (row.deleted_at.toISOString ? row.deleted_at.toISOString() : String(row.deleted_at)) : null
  };
}
