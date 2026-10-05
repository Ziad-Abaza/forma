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

    // 4. Strip privacy-relevant metadata (EXIF/GPS, XMP, IPTC, comments, text chunks).
    //    Fails closed: if the container cannot be parsed, ingestion is rejected
    //    rather than storing a file while claiming it was sanitized.
    const stripped = this.stripMetadata(buffer, detectedMime);

    // 5. Compute SHA-256 hash of the SANITIZED bytes actually stored
    const fileHash = crypto.createHash('sha256').update(stripped).digest('hex');

    // 5. Build secure private storage path (no public URLs)
    const ext = detectedMime === 'image/jpeg' ? 'jpg' : detectedMime === 'image/png' ? 'png' : 'webp';
    const userStorageDir = path.join(this.STORAGE_BASE_DIR, userId);
    fs.mkdirSync(userStorageDir, { recursive: true });

    const storagePath = path.join(userStorageDir, `${fileHash}.${ext}`);
    fs.writeFileSync(storagePath, stripped);

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
        stripped.length,
        fileHash,
        storagePath,
        imageKind,
        JSON.stringify({ originalMime: claimedMimeType, extension: ext, isExifStripped: true })
      ]);

      return mapMediaArtifactRow(res.rows[0]);
    });

    return {
      artifact,
      buffer: stripped,
      base64: stripped.toString('base64')
    };
  }

  /**
   * Removes privacy-relevant metadata segments from a verified image container.
   * Throws if the container structure cannot be parsed — callers must not store
   * a file while claiming metadata was stripped.
   */
  private static stripMetadata(buffer: Buffer, mimeType: string): Buffer {
    switch (mimeType) {
      case 'image/jpeg':
        return this.stripJpegMetadata(buffer);
      case 'image/png':
        return this.stripPngMetadata(buffer);
      case 'image/webp':
        return this.stripWebpMetadata(buffer);
      default:
        return buffer;
    }
  }

  /**
   * JPEG: drop APP1 (Exif/XMP), APP13 (IPTC/Photoshop), and COM segments.
   * All other segments (JFIF APP0, ICC APP2, Adobe APP14, image data) are preserved.
   */
  private static stripJpegMetadata(buffer: Buffer): Buffer {
    // buffer[0..1] = FF D8 (SOI) already verified by sniffMimeType
    const parts: Buffer[] = [buffer.subarray(0, 2)];
    let offset = 2;

    while (offset < buffer.length) {
      // Scan data reached — copy the remainder verbatim
      if (buffer[offset] !== 0xff) {
        parts.push(buffer.subarray(offset));
        break;
      }

      if (offset + 1 >= buffer.length) {
        throw new Error('Malformed JPEG: truncated marker');
      }
      const marker = buffer[offset + 1]!;
      // Standalone markers without length (SOI, EOI, RSTn, TEM)
      if (marker === 0x01 || (marker >= 0xd0 && marker <= 0xd9)) {
        parts.push(buffer.subarray(offset, offset + 2));
        offset += 2;
        if (marker === 0xd9) {
          parts.push(buffer.subarray(offset));
          break;
        }
        continue;
      }

      if (offset + 4 > buffer.length) {
        throw new Error('Malformed JPEG: truncated segment header');
      }

      const segLen = buffer.readUInt16BE(offset + 2);
      if (segLen < 2 || offset + 2 + segLen > buffer.length) {
        throw new Error('Malformed JPEG: invalid segment length');
      }

      const isPrivacySegment = marker === 0xe1 || marker === 0xed || marker === 0xfe;
      if (!isPrivacySegment) {
        parts.push(buffer.subarray(offset, offset + 2 + segLen));
      }
      offset += 2 + segLen;
    }

    return Buffer.concat(parts);
  }

  /**
   * PNG: drop eXIf, tEXt, zTXt, and iTXt chunks. Critical chunks and iCCP are preserved.
   */
  private static stripPngMetadata(buffer: Buffer): Buffer {
    // 8-byte signature already verified by sniffMimeType
    const dropChunks = new Set(['eXIf', 'tEXt', 'zTXt', 'iTXt']);
    const parts: Buffer[] = [buffer.subarray(0, 8)];
    let offset = 8;

    while (offset < buffer.length) {
      if (offset + 8 > buffer.length) {
        throw new Error('Malformed PNG: truncated chunk header');
      }
      const chunkLen = buffer.readUInt32BE(offset);
      const type = buffer.toString('latin1', offset + 4, offset + 8);
      const totalLen = 8 + chunkLen + 4; // length + type + data + CRC
      if (offset + totalLen > buffer.length) {
        throw new Error(`Malformed PNG: chunk '${type}' extends beyond buffer`);
      }
      if (!dropChunks.has(type)) {
        parts.push(buffer.subarray(offset, offset + totalLen));
      }
      offset += totalLen;
      if (type === 'IEND') break;
    }

    return Buffer.concat(parts);
  }

  /**
   * WebP: drop EXIF and XMP  subchunks from the RIFF container and fix the
   * container size field.
   */
  private static stripWebpMetadata(buffer: Buffer): Buffer {
    // 'RIFF' + size + 'WEBP' already verified by sniffMimeType
    const dropChunks = new Set(['EXIF', 'XMP ']);
    const parts: Buffer[] = [buffer.subarray(8, 12)]; // 'WEBP' fourcc
    let offset = 12;

    while (offset < buffer.length) {
      if (offset + 8 > buffer.length) {
        throw new Error('Malformed WebP: truncated chunk header');
      }
      const fourcc = buffer.toString('latin1', offset, offset + 4);
      const chunkLen = buffer.readUInt32LE(offset + 4);
      const paddedLen = 8 + chunkLen + (chunkLen % 2); // chunks are padded to even sizes
      if (offset + paddedLen > buffer.length) {
        throw new Error(`Malformed WebP: chunk '${fourcc}' extends beyond buffer`);
      }
      if (!dropChunks.has(fourcc)) {
        parts.push(buffer.subarray(offset, offset + paddedLen));
      }
      offset += paddedLen;
    }

    const body = Buffer.concat(parts);
    const header = Buffer.alloc(8);
    header.write('RIFF', 0, 'latin1');
    header.writeUInt32LE(4 + body.length, 4); // 'WEBP' + chunks
    return Buffer.concat([header, body]);
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
