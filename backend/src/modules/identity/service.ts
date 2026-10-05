import crypto from 'crypto';
import { withSystemContext } from '../../core/database/index.js';
import {
  hashPassword,
  verifyPassword,
  hashToken,
  generateTokenPair
} from '../../core/security/index.js';
import { AuditService } from '../audit/index.js';
import { IdentityRepository } from './repository.js';
import type { RegisterRequest, LoginRequest, RefreshTokenRequest, AuthResponse } from './contracts.js';

export function calculateAge(dateOfBirth: string): number {
  const dob = new Date(dateOfBirth);
  if (isNaN(dob.getTime())) {
    throw new Error('Invalid date format for date of birth');
  }
  const today = new Date();
  let age = today.getFullYear() - dob.getFullYear();
  const monthDiff = today.getMonth() - dob.getMonth();
  if (monthDiff < 0 || (monthDiff === 0 && today.getDate() < dob.getDate())) {
    age--;
  }
  return age;
}

export class IdentityService {
  /**
   * Registers a new user. Enforces 18+ age gate, creates credentials, consents, and initial profile.
   */
  static async register(
    req: RegisterRequest,
    correlationId: string,
    ipAddress?: string
  ): Promise<AuthResponse> {
    const age = calculateAge(req.dateOfBirth);
    if (age < 18) {
      await AuditService.recordEvent({
        actorType: 'user',
        action: 'user_registration_blocked_underage',
        entityType: 'user',
        entityId: 'unassigned',
        correlationId,
        ipAddress,
        status: 'failure',
        metadata: { reason: 'age_gate_rejection', detectedAge: age }
      });
      throw new Error('Registration blocked: users must be at least 18 years old.');
    }

    return await withSystemContext(async (client) => {
      const existing = await IdentityRepository.findUserByEmail(client, req.email);
      if (existing) {
        throw new Error('Email is already registered.');
      }

      const passwordHash = await hashPassword(req.password);

      const user = await IdentityRepository.createUser(client, {
        email: req.email,
        locale: req.locale,
        numeralSystem: req.numeralSystem
      });

      await IdentityRepository.createCredentials(client, user.id, passwordHash);

      // Record required onboarding consents
      await IdentityRepository.createConsent(client, {
        userId: user.id,
        policyType: 'terms_of_service',
        version: '1.0',
        granted: req.consents.termsOfService
      });
      await IdentityRepository.createConsent(client, {
        userId: user.id,
        policyType: 'health_data_processing',
        version: '1.0',
        granted: req.consents.healthDataProcessing
      });
      await IdentityRepository.createConsent(client, {
        userId: user.id,
        policyType: 'ai_third_party_processing',
        version: '1.0',
        granted: req.consents.aiThirdPartyProcessing
      });

      // Create initial profile
      await IdentityRepository.createInitialProfile(client, {
        userId: user.id,
        dateOfBirth: req.dateOfBirth,
        heightCm: req.heightCm,
        sexForCalculation: req.sexForCalculation
      });

      // Generate initial session and tokens
      const tokens = generateTokenPair({ userId: user.id, email: user.email, role: user.role });
      const familyId = crypto.randomUUID();
      const refreshTokenHash = hashToken(tokens.refreshToken);
      const expiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000); // 30 days

      await IdentityRepository.createSession(client, {
        userId: user.id,
        refreshTokenHash,
        familyId,
        expiresAt
      });

      await AuditService.recordEvent(
        {
          userId: user.id,
          actorType: 'user',
          action: 'user_registered',
          entityType: 'user',
          entityId: user.id,
          correlationId,
          ipAddress,
          status: 'success',
          metadata: { email: user.email, locale: user.locale }
        },
        client
      );

      return {
        user: {
          id: user.id,
          email: user.email,
          role: user.role,
          locale: user.locale,
          numeralSystem: user.numeral_system,
          emailVerified: user.email_verified
        },
        tokens
      };
    });
  }

  /**
   * Authenticates user credentials and issues session tokens.
   */
  static async login(
    req: LoginRequest,
    correlationId: string,
    ipAddress?: string
  ): Promise<AuthResponse> {
    return await withSystemContext(async (client) => {
      const user = await IdentityRepository.findUserByEmail(client, req.email);
      if (!user) {
        await AuditService.recordEvent(
          {
            actorType: 'user',
            action: 'login_failed',
            entityType: 'user',
            entityId: 'unknown',
            correlationId,
            ipAddress,
            status: 'failure',
            metadata: { reason: 'user_not_found' }
          },
          client
        );
        throw new Error('Invalid email or password.');
      }

      const passwordHash = await IdentityRepository.findPasswordHashByUserId(client, user.id);
      if (!passwordHash) {
        throw new Error('Invalid email or password.');
      }

      const isValid = await verifyPassword(passwordHash, req.password);
      if (!isValid) {
        await AuditService.recordEvent(
          {
            userId: user.id,
            actorType: 'user',
            action: 'login_failed',
            entityType: 'user',
            entityId: user.id,
            correlationId,
            ipAddress,
            status: 'failure',
            metadata: { reason: 'invalid_credentials' }
          },
          client
        );
        throw new Error('Invalid email or password.');
      }

      const tokens = generateTokenPair({ userId: user.id, email: user.email, role: user.role });
      const familyId = crypto.randomUUID();
      const refreshTokenHash = hashToken(tokens.refreshToken);
      const expiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);

      await IdentityRepository.createSession(client, {
        userId: user.id,
        deviceInfo: req.deviceInfo,
        refreshTokenHash,
        familyId,
        expiresAt
      });

      await AuditService.recordEvent(
        {
          userId: user.id,
          actorType: 'user',
          action: 'user_logged_in',
          entityType: 'user',
          entityId: user.id,
          correlationId,
          ipAddress,
          status: 'success'
        },
        client
      );

      return {
        user: {
          id: user.id,
          email: user.email,
          role: user.role,
          locale: user.locale,
          numeralSystem: user.numeral_system,
          emailVerified: user.email_verified
        },
        tokens
      };
    });
  }

  /**
   * Refreshes access tokens with automatic refresh token rotation.
   * If a revoked refresh token is presented, detects token reuse and revokes the entire session family!
   */
  static async refreshTokens(
    req: RefreshTokenRequest,
    correlationId: string,
    ipAddress?: string
  ): Promise<AuthResponse> {
    const incomingTokenHash = hashToken(req.refreshToken);

    return await withSystemContext(async (client) => {
      const session = await IdentityRepository.findSessionByTokenHash(client, incomingTokenHash);
      if (!session) {
        throw new Error('Invalid refresh token.');
      }

      // Refresh Token Reuse Detection
      if (session.is_revoked) {
        const revokedCount = await IdentityRepository.revokeSessionFamily(
          client,
          session.user_id,
          session.family_id
        );

        await AuditService.recordEvent(
          {
            userId: session.user_id,
            actorType: 'user',
            action: 'security_alert_refresh_token_reuse',
            entityType: 'session',
            entityId: session.id,
            correlationId,
            ipAddress,
            status: 'failure',
            metadata: {
              familyId: session.family_id,
              sessionsRevoked: revokedCount,
              warning: 'Revoked entire session family due to token reuse detection'
            }
          },
          client
        );

        await client.query('COMMIT');
        throw new Error('Refresh token reuse detected. All active sessions in this family have been revoked.');
      }

      if (new Date(session.expires_at) < new Date()) {
        throw new Error('Refresh token has expired.');
      }

      const user = await IdentityRepository.findUserById(client, session.user_id);
      if (!user) {
        throw new Error('User not found.');
      }

      // Revoke the old session (rotate it)
      await IdentityRepository.revokeSession(client, session.id);

      // Issue new token pair preserving the familyId
      const tokens = generateTokenPair({ userId: user.id, email: user.email, role: user.role });
      const newRefreshTokenHash = hashToken(tokens.refreshToken);
      const expiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);

      await IdentityRepository.createSession(client, {
        userId: user.id,
        refreshTokenHash: newRefreshTokenHash,
        familyId: session.family_id,
        expiresAt
      });

      await AuditService.recordEvent(
        {
          userId: user.id,
          actorType: 'user',
          action: 'token_refreshed',
          entityType: 'session',
          entityId: session.id,
          correlationId,
          ipAddress,
          status: 'success'
        },
        client
      );

      return {
        user: {
          id: user.id,
          email: user.email,
          role: user.role,
          locale: user.locale,
          numeralSystem: user.numeral_system,
          emailVerified: user.email_verified
        },
        tokens
      };
    });
  }

  /**
   * Revokes an active session.
   */
  static async logout(refreshToken: string, correlationId: string): Promise<void> {
    const incomingTokenHash = hashToken(refreshToken);
    await withSystemContext(async (client) => {
      const session = await IdentityRepository.findSessionByTokenHash(client, incomingTokenHash);
      if (session) {
        await IdentityRepository.revokeSession(client, session.id);
        await AuditService.recordEvent(
          {
            userId: session.user_id,
            actorType: 'user',
            action: 'user_logged_out',
            entityType: 'session',
            entityId: session.id,
            correlationId,
            status: 'success'
          },
          client
        );
      }
    });
  }

  /**
   * Retrieves current user summary.
   */
  static async getCurrentUser(userId: string): Promise<UserRecord | null> {
    return await withSystemContext(async (client) => {
      return await IdentityRepository.findUserById(client, userId);
    });
  }

  /**
   * Updates user preferences (locale, numeral_system).
   */
  static async updateUserPreferences(
    userId: string,
    preferences: { locale?: string; numeralSystem?: string },
    correlationId: string
  ): Promise<UserRecord> {
    return await withSystemContext(async (client) => {
      const updated = await IdentityRepository.updateUserPreferences(client, userId, preferences);
      await AuditService.recordEvent(
        {
          userId,
          actorType: 'user',
          action: 'user_preferences_updated',
          entityType: 'user',
          entityId: userId,
          correlationId,
          status: 'success',
          metadata: preferences
        },
        client
      );
      return updated;
    });
  }
}

