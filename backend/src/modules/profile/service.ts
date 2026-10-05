import { withUserContext } from '../../core/database/index.js';
import { AuditService } from '../audit/index.js';
import { ProfileRepository } from './repository.js';
import { calculateAge } from '../identity/service.js';
import type { UpdateProfileRequest, ProfileResponse, ProfileHistoryEntry } from './contracts.js';

export class ProfileService {
  static async getProfile(userId: string): Promise<ProfileResponse | null> {
    return await withUserContext(userId, async (client) => {
      return await ProfileRepository.getProfileByUserId(client, userId);
    });
  }

  static async updateProfile(
    userId: string,
    req: UpdateProfileRequest,
    correlationId: string,
    actor = 'user'
  ): Promise<ProfileResponse> {
    return await withUserContext(userId, async (client) => {
      const current = await ProfileRepository.getProfileByUserId(client, userId);
      if (!current) {
        throw new Error('Profile not found');
      }

      // Check calculation-relevant attributes and record history for reproducibility
      if (req.dateOfBirth !== undefined && req.dateOfBirth !== current.dateOfBirth) {
        const newAge = calculateAge(req.dateOfBirth);
        if (newAge < 18) {
          throw new Error('Date of birth must indicate an adult (18+) user.');
        }
        await ProfileRepository.recordAttributeHistory(
          client,
          userId,
          'date_of_birth',
          current.dateOfBirth,
          req.dateOfBirth,
          actor
        );
      }

      if (req.heightCm !== undefined && req.heightCm !== current.heightCm) {
        await ProfileRepository.recordAttributeHistory(
          client,
          userId,
          'height_cm',
          current.heightCm,
          req.heightCm,
          actor
        );
      }

      if (req.sexForCalculation !== undefined && req.sexForCalculation !== current.sexForCalculation) {
        await ProfileRepository.recordAttributeHistory(
          client,
          userId,
          'sex_for_calculation',
          current.sexForCalculation,
          req.sexForCalculation,
          actor
        );
      }

      if (req.activityLevel !== undefined && req.activityLevel !== current.activityLevel) {
        await ProfileRepository.recordAttributeHistory(
          client,
          userId,
          'activity_level',
          current.activityLevel,
          req.activityLevel,
          actor
        );
      }

      const updated = await ProfileRepository.updateProfile(client, userId, req);

      await AuditService.recordEvent(
        {
          userId,
          actorType: 'user',
          action: 'profile_updated',
          entityType: 'profile',
          entityId: userId,
          correlationId,
          status: 'success',
          metadata: { updatedFields: Object.keys(req) }
        },
        client
      );

      return updated;
    });
  }

  static async getHistory(userId: string, attributeName?: string): Promise<ProfileHistoryEntry[]> {
    return await withUserContext(userId, async (client) => {
      return await ProfileRepository.getProfileHistory(client, userId, attributeName);
    });
  }
}
