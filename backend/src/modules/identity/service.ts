/**
 * Identity & Sessions Domain (ADR-012, §7.2, §20.1)
 *
 * Requirements:
 * - First-party email + password with bcrypt hashing.
 * - Age verification gate: date of birth must indicate user is at least 18 years old.
 * - Rotating refresh tokens bound to device sessions with reuse detection.
 * - Explicit consent records (health data processing + third-party AI processing).
 */

import bcrypt from 'bcryptjs';
import crypto from 'crypto';

export interface User {
  id: string;
  email: string;
  passwordHash: string;
  dateOfBirth: string; // YYYY-MM-DD
  isEmailVerified: boolean;
  status: 'active' | 'suspended' | 'pending_deletion';
  createdAt: string;
  updatedAt: string;
}

export interface ConsentRecord {
  id: string;
  userId: string;
  consentType: 'health_data_processing' | 'third_party_ai_processing';
  version: string;
  granted: boolean;
  grantedAt: string;
  revokedAt?: string;
}

export interface Session {
  id: string;
  userId: string;
  deviceId: string;
  deviceName?: string;
  refreshTokenHash: string;
  isRevoked: boolean;
  createdAt: string;
  expiresAt: string;
  lastUsedAt: string;
}

export class IdentityService {
  private static readonly SALT_ROUNDS = 12;
  private static readonly MIN_AGE_YEARS = 18;

  /**
   * Verify age gate requirement (ADR-012, §10.6, §20.1).
   */
  static verifyAge(dateOfBirthIso: string): boolean {
    const dob = new Date(dateOfBirthIso);
    if (isNaN(dob.getTime())) {
      throw new Error('Invalid date of birth format');
    }
    const today = new Date();
    let age = today.getFullYear() - dob.getFullYear();
    const m = today.getMonth() - dob.getMonth();
    if (m < 0 || (m === 0 && today.getDate() < dob.getDate())) {
      age--;
    }
    return age >= this.MIN_AGE_YEARS;
  }

  /**
   * Securely hash password using bcrypt.
   */
  static async hashPassword(password: string): Promise<string> {
    if (password.length < 8) {
      throw new Error('Password must be at least 8 characters long');
    }
    return bcrypt.hash(password, this.SALT_ROUNDS);
  }

  /**
   * Verify password against hash.
   */
  static async verifyPassword(password: string, hash: string): Promise<boolean> {
    return bcrypt.compare(password, hash);
  }

  /**
   * Generate an unpredictable cryptographically secure token and its hash.
   */
  static generateRefreshToken(): { token: string; hash: string } {
    const token = crypto.randomBytes(40).toString('hex');
    const hash = crypto.createHash('sha256').update(token).digest('hex');
    return { token, hash };
  }

  /**
   * Verify a provided refresh token against the stored hash.
   */
  static verifyTokenHash(token: string, storedHash: string): boolean {
    const hash = crypto.createHash('sha256').update(token).digest('hex');
    return crypto.timingSafeEqual(Buffer.from(hash), Buffer.from(storedHash));
  }
}
