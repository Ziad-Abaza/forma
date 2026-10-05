import fastify, { type FastifyInstance, type FastifyRequest, type FastifyReply } from 'fastify';
import cors from '@fastify/cors';
import crypto from 'crypto';
import { config } from './config/index.js';
import { verifyJwt } from './core/security/index.js';
import { checkDatabaseHealth } from './core/database/index.js';
import { appLogger } from './core/logging/index.js';
import { IdentityService } from './modules/identity/service.js';
import {
  RegisterRequestSchema,
  LoginRequestSchema,
  RefreshTokenRequestSchema,
  UpdatePreferencesRequestSchema
} from './modules/identity/contracts.js';
import { MeasurementsService } from './modules/measurements/service.js';
import {
  CreateObservationRequestSchema,
  SupersedeObservationRequestSchema,
  VoidObservationRequestSchema,
  QueryObservationsFilterSchema
} from './modules/measurements/contracts.js';
import { ProfileService } from './modules/profile/service.js';
import { UpdateProfileRequestSchema } from './modules/profile/contracts.js';
import { PrivacyOrchestrator } from './modules/privacy/index.js';
import { GoalsService } from './modules/goals/service.js';
import { CreateGoalRequestSchema, UpdateGoalVersionRequestSchema, GoalStatusSchema } from './modules/goals/contracts.js';
import { CalculationEngine } from './modules/calculations/engine.js';
import { AnalyticsService } from './modules/analytics/service.js';
import {
  AssistantOrchestrator,
  ActionProposalEngine,
  AssistantMemoryService,
  AssistantPrivacyContract,
  ChatRequestSchema,
  ConfirmProposalSchema,
  SaveMemorySchema
} from './modules/assistant/index.js';
import {
  MediaPipeline,
  VisionExtractor,
  DraftReviewService,
  MultimodalPrivacyContract,
  UploadAndExtractRequestSchema,
  UpdateDraftFieldSchema,
  CommitDraftRequestSchema
} from './modules/multimodal/index.js';
import { IntegrationsPrivacyContract } from './modules/integrations/index.js';
import { z } from 'zod';
import { BYOKService } from './modules/ai/gateway/byok.js';
import { ModelRegistry } from './modules/ai/gateway/registry.js';
import { AIGateway } from './modules/ai/gateway/gateway.js';
import { AuditService } from './modules/audit/index.js';

export interface AuthenticatedUser {
  userId: string;
  email: string;
  role: string;
}

export interface AppDependencies {
  aiGateway?: AIGateway;
}

declare module 'fastify' {
  interface FastifyRequest {
    user?: AuthenticatedUser;
    correlationId: string;
    startTime: number;
  }
}

export function buildApp(deps: AppDependencies = {}): FastifyInstance {
  const app = fastify({
    logger: false // Logging handled by structured sanitized logger
  });

  // Enable CORS against an explicit allowlist (CORS_ORIGINS env var).
  // Bearer-token auth means browsers still require an allowlisted origin;
  // non-browser clients (mobile app) send no Origin header and are unaffected.
  const corsAllowlist = (config.CORS_ORIGINS ?? '')
    .split(',')
    .map((o) => o.trim())
    .filter((o) => o.length > 0);
  const allowDevOrigins = config.NODE_ENV !== 'production';

  app.register(cors, {
    origin: (origin, cb) => {
      if (!origin) {
        cb(null, true);
        return;
      }
      if (corsAllowlist.includes(origin)) {
        cb(null, true);
        return;
      }
      if (allowDevOrigins && /^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(origin)) {
        cb(null, true);
        return;
      }
      cb(null, false);
    },
    credentials: false
  });

  // Support empty JSON bodies gracefully (e.g. DELETE or bodyless requests with application/json header)
  app.addContentTypeParser('application/json', { parseAs: 'string' }, (_req, body, done) => {
    if (!body || (typeof body === 'string' && body.trim().length === 0)) {
      done(null, {});
      return;
    }
    try {
      done(null, JSON.parse(body as string));
    } catch (err: any) {
      err.statusCode = 400;
      done(err, undefined);
    }
  });

  // Middleware: Attach correlation ID and start time to every request
  app.addHook('onRequest', async (req: FastifyRequest) => {
    req.correlationId = (req.headers['x-correlation-id'] as string) || crypto.randomUUID();
    req.startTime = Date.now();
  });

  // Middleware: Structured request/response telemetry with automated PII redaction
  app.addHook('onResponse', async (req: FastifyRequest, reply: FastifyReply) => {
    const durationMs = Date.now() - (req.startTime || Date.now());
    const meta = {
      correlationId: req.correlationId,
      method: req.method,
      url: req.url,
      statusCode: reply.statusCode,
      durationMs,
      userId: req.user?.userId
    };

    if (reply.statusCode >= 500) {
      appLogger.error(`HTTP request completed with server error`, meta);
    } else {
      appLogger.info(`HTTP request completed`, meta);
    }
  });

  // Authentication hook helper
  const requireAuth = async (req: FastifyRequest, reply: FastifyReply) => {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return reply.status(401).send({ error: 'Unauthorized: missing or invalid Authorization header' });
    }

    const token = authHeader.substring(7);
    try {
      const payload = verifyJwt(token, config.JWT_ACCESS_SECRET);
      req.user = payload;
    } catch (err: any) {
      return reply.status(401).send({ error: 'Unauthorized: ' + err.message });
    }
  };

  // Global Error Handler
  app.setErrorHandler((error: Error & { statusCode?: number }, req, reply) => {
    const statusCode = error.statusCode || 400;
    appLogger.error(`Unhandled request error: ${error.message}`, {
      correlationId: req.correlationId,
      statusCode,
      stack: error.stack
    });
    reply.status(statusCode).send({
      error: error.message || 'An unexpected error occurred',
      correlationId: req.correlationId
    });
  });

  // --- Observability & Health Probes (Blueprint §20, Gate 12) ---
  app.get('/health', async () => {
    return {
      status: 'healthy',
      version: '1.0.0',
      timestamp: new Date().toISOString()
    };
  });

  app.get('/health/live', async () => {
    return {
      status: 'healthy',
      uptimeSeconds: Math.floor(process.uptime()),
      timestamp: new Date().toISOString()
    };
  });

  app.get('/health/ready', async (_req, reply) => {
    const isDbReady = await checkDatabaseHealth();
    if (!isDbReady) {
      return reply.status(503).send({
        status: 'unhealthy',
        database: 'disconnected',
        timestamp: new Date().toISOString()
      });
    }
    return reply.status(200).send({
      status: 'ready',
      database: 'connected',
      timestamp: new Date().toISOString()
    });
  });

  app.get('/metrics', async () => {
    return {
      status: 'operational',
      environment: config.NODE_ENV,
      uptimeSeconds: Math.floor(process.uptime()),
      memory: process.memoryUsage(),
      timestamp: new Date().toISOString()
    };
  });

  // --- Identity & Auth Routes ---
  app.post('/api/v1/auth/register', async (req, reply) => {
    const parsed = RegisterRequestSchema.parse(req.body);
    const result = await IdentityService.register(parsed, req.correlationId, req.ip);
    return reply.status(201).send(result);
  });

  app.post('/api/v1/auth/login', async (req, reply) => {
    const parsed = LoginRequestSchema.parse(req.body);
    const result = await IdentityService.login(parsed, req.correlationId, req.ip);
    return reply.status(200).send(result);
  });

  app.post('/api/v1/auth/refresh', async (req, reply) => {
    const parsed = RefreshTokenRequestSchema.parse(req.body);
    const result = await IdentityService.refreshTokens(parsed, req.correlationId, req.ip);
    return reply.status(200).send(result);
  });

  app.post('/api/v1/auth/logout', async (req, reply) => {
    const parsed = RefreshTokenRequestSchema.parse(req.body);
    await IdentityService.logout(parsed.refreshToken, req.correlationId);
    return reply.status(200).send({ message: 'Successfully logged out' });
  });

  app.post('/api/v1/auth/logout-all', { preHandler: [requireAuth] }, async (req, reply) => {
    const revoked = await IdentityService.revokeAllSessions(req.user!.userId, req.correlationId);
    return reply.send({ success: true, sessionsRevoked: revoked });
  });

  app.get('/api/v1/auth/sessions', { preHandler: [requireAuth] }, async (req, reply) => {
    const sessions = await IdentityService.listSessions(req.user!.userId);
    return reply.send({
      sessions: sessions.map((s) => ({
        id: s.id,
        deviceInfo: s.device_info,
        familyId: s.family_id,
        isRevoked: s.is_revoked,
        expiresAt: s.expires_at,
        createdAt: s.created_at
      }))
    });
  });

  app.delete('/api/v1/auth/sessions/:id', { preHandler: [requireAuth] }, async (req, reply) => {
    const { id } = req.params as { id: string };
    const revoked = await IdentityService.revokeSession(req.user!.userId, id, req.correlationId);
    if (!revoked) {
      return reply.status(404).send({ error: 'Session not found' });
    }
    return reply.send({ success: true });
  });

  app.post('/api/v1/auth/change-password', { preHandler: [requireAuth] }, async (req, reply) => {
    const parsed = z.object({
      currentPassword: z.string().min(1),
      newPassword: z.string().min(8)
    }).parse(req.body);
    await IdentityService.changePassword(
      req.user!.userId,
      parsed.currentPassword,
      parsed.newPassword,
      req.correlationId
    );
    return reply.send({ success: true, message: 'Password updated. Please sign in again.' });
  });

  app.get('/api/v1/auth/me', { preHandler: [requireAuth] }, async (req, reply) => {
    const user = await IdentityService.getCurrentUser(req.user!.userId);
    if (!user) {
      return reply.status(404).send({ error: 'User not found' });
    }
    return reply.send({
      id: user.id,
      email: user.email,
      role: user.role,
      locale: user.locale,
      numeralSystem: user.numeral_system,
      emailVerified: user.email_verified
    });
  });

  app.patch('/api/v1/auth/preferences', { preHandler: [requireAuth] }, async (req, reply) => {
    const parsed = UpdatePreferencesRequestSchema.parse(req.body);
    const updated = await IdentityService.updateUserPreferences(req.user!.userId, parsed, req.correlationId);
    return reply.send({
      id: updated.id,
      email: updated.email,
      role: updated.role,
      locale: updated.locale,
      numeralSystem: updated.numeral_system,
      emailVerified: updated.email_verified
    });
  });

  // --- Profile Routes ---
  app.get('/api/v1/profile', { preHandler: [requireAuth] }, async (req, reply) => {
    const profile = await ProfileService.getProfile(req.user!.userId);
    if (!profile) {
      return reply.status(404).send({ error: 'Profile not found' });
    }
    return reply.send(profile);
  });

  app.put('/api/v1/profile', { preHandler: [requireAuth] }, async (req, reply) => {
    const parsed = UpdateProfileRequestSchema.parse(req.body);
    const updated = await ProfileService.updateProfile(req.user!.userId, parsed, req.correlationId);
    return reply.send(updated);
  });

  app.get('/api/v1/profile/history', { preHandler: [requireAuth] }, async (req, reply) => {
    const { attribute } = req.query as { attribute?: string };
    const history = await ProfileService.getHistory(req.user!.userId, attribute);
    return reply.send({ history });
  });

  // --- Measurements & Observations Routes ---
  app.get('/api/v1/measurements/types', async () => {
    const types = await MeasurementsService.listTypes();
    return { types };
  });

  app.post('/api/v1/measurements/observations', { preHandler: [requireAuth] }, async (req, reply) => {
    const parsed = CreateObservationRequestSchema.parse(req.body);
    const result = await MeasurementsService.recordObservation(req.user!.userId, parsed, req.correlationId);
    return reply.status(201).send(result);
  });

  app.get('/api/v1/measurements/observations', { preHandler: [requireAuth] }, async (req, reply) => {
    const filter = QueryObservationsFilterSchema.parse(req.query);
    const observations = await MeasurementsService.queryObservations(req.user!.userId, filter);
    return reply.send({ observations });
  });

  app.post('/api/v1/measurements/observations/:id/supersede', { preHandler: [requireAuth] }, async (req, reply) => {
    const { id } = req.params as { id: string };
    const body = req.body as Record<string, unknown>;
    const parsed = SupersedeObservationRequestSchema.parse({
      ...body,
      previousObservationId: id
    });
    const result = await MeasurementsService.supersedeObservation(req.user!.userId, parsed, req.correlationId);
    return reply.send(result);
  });

  app.post('/api/v1/measurements/observations/:id/void', { preHandler: [requireAuth] }, async (req, reply) => {
    const { id } = req.params as { id: string };
    const body = req.body as Record<string, unknown>;
    const parsed = VoidObservationRequestSchema.parse({
      ...body,
      observationId: id
    });
    const result = await MeasurementsService.voidObservation(req.user!.userId, parsed, req.correlationId);
    return reply.send(result);
  });

  app.get('/api/v1/measurements/provenance/:id', { preHandler: [requireAuth] }, async (req, reply) => {
    const { id } = req.params as { id: string };
    const provenance = await MeasurementsService.getProvenance(req.user!.userId, id);
    if (!provenance) {
      return reply.status(404).send({ error: 'Provenance record not found' });
    }
    return reply.send(provenance);
  });

  // --- Privacy Routes (Export & Deletion Contracts) ---
  app.get('/api/v1/privacy/consents', { preHandler: [requireAuth] }, async (req, reply) => {
    const consents = await IdentityService.listConsents(req.user!.userId);
    return reply.send({
      consents: consents.map((c) => ({
        policyType: c.policy_type,
        version: c.version,
        granted: c.granted,
        grantedAt: c.granted_at,
        withdrawnAt: c.withdrawn_at
      }))
    });
  });

  app.post('/api/v1/privacy/consents/:policyType/withdraw', { preHandler: [requireAuth] }, async (req, reply) => {
    const { policyType } = req.params as { policyType: string };
    await IdentityService.withdrawConsent(req.user!.userId, policyType, req.correlationId);
    return reply.send({ success: true, policyType, withdrawnAt: new Date().toISOString() });
  });

  app.get('/api/v1/privacy/export', { preHandler: [requireAuth] }, async (req, reply) => {
    const exportData = await PrivacyOrchestrator.exportAllUserData(req.user!.userId, req.correlationId);
    return reply.send(exportData);
  });

  app.delete('/api/v1/privacy/account', { preHandler: [requireAuth] }, async (req, reply) => {
    const purgeResult = await PrivacyOrchestrator.purgeUserAccount(req.user!.userId, req.correlationId);
    return reply.send(purgeResult);
  });

  // --- Goals Routes ---
  const goalsService = new GoalsService();
  const calculationEngine = new CalculationEngine();
  const analyticsService = new AnalyticsService();

  app.post('/api/v1/goals', { preHandler: [requireAuth] }, async (req, reply) => {
    const parsed = CreateGoalRequestSchema.parse(req.body);
    const goal = await goalsService.createGoal(req.user!.userId, parsed);
    return reply.status(201).send(goal);
  });

  app.post('/api/v1/goals/:id/versions', { preHandler: [requireAuth] }, async (req, reply) => {
    const { id } = req.params as { id: string };
    const parsed = UpdateGoalVersionRequestSchema.parse(req.body);
    const goal = await goalsService.addGoalVersion(req.user!.userId, id, parsed);
    return reply.send(goal);
  });

  app.get('/api/v1/goals/primary', { preHandler: [requireAuth] }, async (req, reply) => {
    const goal = await goalsService.getPrimaryGoal(req.user!.userId);
    return reply.send({ goal });
  });

  app.get('/api/v1/goals', { preHandler: [requireAuth] }, async (req, reply) => {
    const goals = await goalsService.listGoals(req.user!.userId);
    return reply.send({ goals });
  });

  app.get('/api/v1/goals/:id/versions', { preHandler: [requireAuth] }, async (req, reply) => {
    const { id } = req.params as { id: string };
    const versions = await goalsService.listGoalVersions(req.user!.userId, id);
    return reply.send({ versions });
  });

  app.patch('/api/v1/goals/:id/status', { preHandler: [requireAuth] }, async (req, reply) => {
    const { id } = req.params as { id: string };
    const parsed = z.object({ status: GoalStatusSchema }).safeParse(req.body);
    if (!parsed.success) {
      return reply.status(400).send({ error: "Status must be one of: active, achieved, abandoned, superseded" });
    }
    const success = await goalsService.updateGoalStatus(req.user!.userId, id, parsed.data.status);
    return reply.send({ success, status: parsed.data.status });
  });

  // --- Calculations Routes (Pure, Deterministic) ---
  app.get('/api/v1/calculations/bmi', async (req, reply) => {
    const query = req.query as { weightKg?: string; heightCm?: string };
    const weight = query.weightKg ? Number(query.weightKg) : undefined;
    const height = query.heightCm ? Number(query.heightCm) : undefined;
    const result = calculationEngine.calculateBmi(weight, height);
    return reply.send(result);
  });

  app.get('/api/v1/calculations/bmr', async (req, reply) => {
    const query = req.query as {
      weightKg?: string;
      heightCm?: string;
      ageYears?: string;
      sex?: 'male' | 'female' | 'other';
      leanBodyMassKg?: string;
    };
    const result = calculationEngine.calculateBmr({
      weightKg: query.weightKg ? Number(query.weightKg) : undefined,
      heightCm: query.heightCm ? Number(query.heightCm) : undefined,
      ageYears: query.ageYears ? Number(query.ageYears) : undefined,
      sex: query.sex,
      leanBodyMassKg: query.leanBodyMassKg ? Number(query.leanBodyMassKg) : undefined
    });
    return reply.send(result);
  });

  app.get('/api/v1/calculations/tdee', async (req, reply) => {
    const query = req.query as { bmr?: string; activityLevel?: any };
    const bmr = query.bmr ? Number(query.bmr) : 0;
    const result = calculationEngine.calculateTdee(bmr, query.activityLevel);
    return reply.send(result);
  });

  app.get('/api/v1/calculations/calorie-targets', async (req, reply) => {
    const query = req.query as { tdee?: string; sex?: 'male' | 'female'; isPregnant?: string; hasMedicalCondition?: string };
    const tdee = query.tdee ? Number(query.tdee) : 0;
    const result = calculationEngine.calculateCalorieTargets({
      tdee,
      sex: query.sex,
      specialFlags: {
        isPregnant: query.isPregnant === 'true',
        hasMedicalCondition: query.hasMedicalCondition === 'true'
      }
    });
    return reply.send(result);
  });

  app.get('/api/v1/calculations/macros', async (req, reply) => {
    const query = req.query as { targetCalories?: string; weightKg?: string };
    const targetCalories = query.targetCalories ? Number(query.targetCalories) : 2000;
    const weightKg = query.weightKg ? Number(query.weightKg) : 70;
    const result = calculationEngine.calculateMacroDistribution(targetCalories, weightKg);
    return reply.send(result);
  });

  app.get('/api/v1/calculations/timeline', async (req, reply) => {
    const query = req.query as { currentWeightKg?: string; targetWeightKg?: string; weeklyRateKg?: string; startDate?: string };
    const result = calculationEngine.projectWeightTimeline({
      currentWeightKg: query.currentWeightKg ? Number(query.currentWeightKg) : undefined,
      targetWeightKg: query.targetWeightKg ? Number(query.targetWeightKg) : undefined,
      weeklyRateKg: query.weeklyRateKg ? Number(query.weeklyRateKg) : undefined,
      startDate: query.startDate ? new Date(query.startDate) : undefined
    });
    return reply.send(result);
  });

  // --- Analytics & Snapshot Routes ---
  app.get('/api/v1/analytics/snapshot', { preHandler: [requireAuth] }, async (req, reply) => {
    const snapshot = await analyticsService.getSnapshot(req.user!.userId);
    return reply.send(snapshot);
  });

  app.get('/api/v1/analytics/snapshot/reconcile', { preHandler: [requireAuth] }, async (req, reply) => {
    const reconciliation = await analyticsService.reconcileSnapshot(req.user!.userId);
    return reply.send(reconciliation);
  });

  app.get('/api/v1/analytics/trends/:typeCode', { preHandler: [requireAuth] }, async (req, reply) => {
    const { typeCode } = req.params as { typeCode: string };
    const query = req.query as { windowDays?: string };
    const windowDays = query.windowDays ? Number(query.windowDays) : 30;
    const trend = await analyticsService.getTrend(req.user!.userId, typeCode, windowDays);
    return reply.send(trend);
  });

  // --- Assistant & Controlled Actions Routes (Blueprint §10, §11, §12) ---
  const assistantOrchestrator = new AssistantOrchestrator();
  PrivacyOrchestrator.registerModule(new AssistantPrivacyContract());

  app.post('/api/v1/assistant/chat', { preHandler: [requireAuth] }, async (req, reply) => {
    const parsed = ChatRequestSchema.parse(req.body);
    const userId = req.user!.userId;

    // Sending health context to a third-party AI provider requires active consent.
    const aiConsent = await IdentityService.hasActiveConsent(userId, 'ai_third_party_processing');
    if (!aiConsent) {
      return reply.status(403).send({
        error: 'AI processing consent has not been granted or was withdrawn.',
        code: 'AI_CONSENT_REQUIRED'
      });
    }

    if (parsed.stream) {
      reply.raw.setHeader('Content-Type', 'text/event-stream');
      reply.raw.setHeader('Cache-Control', 'no-cache');
      reply.raw.setHeader('Connection', 'keep-alive');
      // CORS is handled by the @fastify/cors allowlist — no manual wildcard header.

      try {
        for await (const event of assistantOrchestrator.chatStream(userId, parsed, req.correlationId)) {
          reply.raw.write(`event: ${event.event}\ndata: ${JSON.stringify(event.data)}\n\n`);
        }
      } catch (err: any) {
        reply.raw.write(`event: error\ndata: ${JSON.stringify({ code: 'S02', retryable: true })}\n\n`);
      } finally {
        reply.raw.end();
      }
      return;
    }

    const result = await assistantOrchestrator.chat(userId, parsed, req.correlationId);
    return reply.send(result);
  });

  app.get('/api/v1/assistant/conversations', { preHandler: [requireAuth] }, async (req, reply) => {
    const list = await assistantOrchestrator.listConversations(req.user!.userId);
    return reply.send({ conversations: list });
  });

  app.get('/api/v1/assistant/conversations/:id', { preHandler: [requireAuth] }, async (req, reply) => {
    const { id } = req.params as { id: string };
    const conv = await assistantOrchestrator.getConversation(req.user!.userId, id);
    if (!conv) {
      return reply.status(404).send({ error: 'Conversation not found' });
    }
    return reply.send(conv);
  });

  app.delete('/api/v1/assistant/conversations/:id', { preHandler: [requireAuth] }, async (req, reply) => {
    const { id } = req.params as { id: string };
    const deleted = await assistantOrchestrator.deleteConversation(req.user!.userId, id);
    return reply.send({ success: deleted });
  });

  app.post('/api/v1/assistant/proposals/:id/confirm', { preHandler: [requireAuth] }, async (req, reply) => {
    const { id } = req.params as { id: string };
    const parsed = ConfirmProposalSchema.parse(req.body || {});
    const result = await ActionProposalEngine.confirmProposal(
      req.user!.userId,
      id,
      req.correlationId,
      parsed.idempotencyKey
    );
    return reply.send(result);
  });

  app.post('/api/v1/assistant/proposals/:id/decline', { preHandler: [requireAuth] }, async (req, reply) => {
    const { id } = req.params as { id: string };
    const proposal = await ActionProposalEngine.declineProposal(req.user!.userId, id, req.correlationId);
    return reply.send({ proposal });
  });

  app.get('/api/v1/assistant/memories', { preHandler: [requireAuth] }, async (req, reply) => {
    const query = req.query as { category?: string };
    const memories = await AssistantMemoryService.getMemories(req.user!.userId, query.category);
    return reply.send({ memories });
  });

  app.post('/api/v1/assistant/memories', { preHandler: [requireAuth] }, async (req, reply) => {
    const parsed = SaveMemorySchema.parse(req.body);
    const memory = await AssistantMemoryService.saveMemory(req.user!.userId, parsed, undefined, 'user_explicit');
    return reply.status(201).send({ memory });
  });

  app.delete('/api/v1/assistant/memories/:id', { preHandler: [requireAuth] }, async (req, reply) => {
    const { id } = req.params as { id: string };
    const deleted = await AssistantMemoryService.deleteMemory(req.user!.userId, id);
    return reply.send({ success: deleted });
  });

  // --- AI Configuration & BYOK Routes (Blueprint §10, §20.5, ADR-018) ---
  const byokService = new BYOKService();
  const aiGateway = deps.aiGateway ?? new AIGateway(byokService);

  const StoreCredentialSchema = z.object({
    provider: z.string().min(1).max(64),
    apiKey: z.string().min(8).max(256),
  });

  app.get('/api/v1/ai/config', { preHandler: [requireAuth] }, async (req, reply) => {
    const userId = req.user!.userId;
    const credentials = await byokService.listUserCredentials(userId);
    const activeProvider = await byokService.getActiveProvider(userId);
    const models = ModelRegistry.getAllModels();

    return reply.send({
      activeProvider,
      availableProviders: aiGateway.getRegisteredProviders(),
      models,
      credentials,
    });
  });

  const UpdateAIPreferencesSchema = z.object({
    activeProvider: z.string().min(1).max(64),
  });

  app.patch('/api/v1/ai/preferences', { preHandler: [requireAuth] }, async (req, reply) => {
    const parsed = UpdateAIPreferencesSchema.parse(req.body);
    const userId = req.user!.userId;

    await byokService.setActiveProvider(userId, parsed.activeProvider);

    await AuditService.recordEvent({
      userId,
      actorType: 'user',
      action: 'ai_preference_updated',
      entityType: 'user_ai_preferences',
      entityId: parsed.activeProvider,
      correlationId: req.correlationId,
      status: 'success',
      metadata: { activeProvider: parsed.activeProvider },
    });

    return reply.send({ success: true, activeProvider: parsed.activeProvider });
  });

  app.post('/api/v1/ai/credentials', { preHandler: [requireAuth] }, async (req, reply) => {
    const parsed = StoreCredentialSchema.parse(req.body);
    const userId = req.user!.userId;

    const cred = await byokService.storeUserKey(userId, parsed.provider, parsed.apiKey);

    await AuditService.recordEvent({
      userId,
      actorType: 'user',
      action: 'ai_credential_stored',
      entityType: 'user_ai_credentials',
      entityId: cred.id,
      correlationId: req.correlationId,
      status: 'success',
      metadata: { provider: parsed.provider, fingerprint: cred.keyFingerprint },
    });

    return reply.status(201).send({ credential: cred });
  });

  app.delete('/api/v1/ai/credentials/:provider', { preHandler: [requireAuth] }, async (req, reply) => {
    const { provider } = req.params as { provider: string };
    const userId = req.user!.userId;

    const deleted = await byokService.deleteUserKey(userId, provider);

    await AuditService.recordEvent({
      userId,
      actorType: 'user',
      action: 'ai_credential_deleted',
      entityType: 'user_ai_credentials',
      entityId: provider,
      correlationId: req.correlationId,
      status: 'success',
      metadata: { provider },
    });

    return reply.send({ success: deleted });
  });

  app.post('/api/v1/ai/test-connection', { preHandler: [requireAuth] }, async (req, reply) => {
    const body = req.body as { provider?: string; apiKey?: string };
    const provider = (body.provider || 'google').toLowerCase();

    if (!byokService.isProviderAllowed(provider)) {
      return reply.status(400).send({ error: `Provider '${provider}' is not supported` });
    }

    let keyToTest = body.apiKey;
    if (!keyToTest || keyToTest.trim().length === 0) {
      keyToTest = await byokService.resolveUserKey(req.user!.userId, provider);
    }

    if (!keyToTest || keyToTest.length < 8) {
      return reply.status(400).send({ error: `No API key provided or stored for provider '${provider}'` });
    }

    try {
      const adapter = aiGateway.getAdapter(provider);
      if (!adapter) {
        return reply.status(400).send({ error: `Adapter for '${provider}' not registered` });
      }
      const modelId = ModelRegistry.getDefaultModelForProvider(provider, 'general_qa');
      await adapter.generateText(modelId, { prompt: 'ping', maxTokens: 4 }, keyToTest);

      return reply.send({
        status: 'success',
        provider,
        message: `Connection test verified for provider ${provider}`,
      });
    } catch (err: any) {
      return reply.status(400).send({
        error: `Provider ${provider} connection failed: ${err.message || err}`,
        status: 'failed',
      });
    }
  });

  // --- Multimodal & Vision Extraction Routes (Blueprint §13, §14) ---
  PrivacyOrchestrator.registerModule(new MultimodalPrivacyContract());

  app.post('/api/v1/multimodal/upload-and-extract', { preHandler: [requireAuth] }, async (req, reply) => {
    const parsed = UploadAndExtractRequestSchema.parse(req.body);
    const userId = req.user!.userId;

    const media = await MediaPipeline.ingestImage(
      userId,
      parsed.imageBase64,
      parsed.mimeType,
      parsed.imageKindHint
    );

    const draft = await VisionExtractor.extractFromImage({
      userId,
      mediaArtifact: media.artifact,
      base64Image: media.base64,
      kindHint: parsed.imageKindHint,
      correlationId: req.correlationId
    });

    return reply.status(201).send({ draft, artifact: media.artifact });
  });

  app.get('/api/v1/multimodal/drafts', { preHandler: [requireAuth] }, async (req, reply) => {
    const { status } = req.query as { status?: string };
    const drafts = await DraftReviewService.listDrafts(req.user!.userId, status);
    return reply.send({ drafts });
  });

  app.get('/api/v1/multimodal/drafts/:id', { preHandler: [requireAuth] }, async (req, reply) => {
    const { id } = req.params as { id: string };
    const draft = await DraftReviewService.getDraft(req.user!.userId, id);
    if (!draft) {
      return reply.status(404).send({ error: 'Extraction draft not found' });
    }
    return reply.send({ draft });
  });

  app.put('/api/v1/multimodal/drafts/:id/fields', { preHandler: [requireAuth] }, async (req, reply) => {
    const { id } = req.params as { id: string };
    const parsed = UpdateDraftFieldSchema.parse(req.body);
    const updated = await DraftReviewService.updateDraftField(req.user!.userId, id, parsed);
    return reply.send({ draft: updated });
  });

  app.post('/api/v1/multimodal/drafts/:id/commit', { preHandler: [requireAuth] }, async (req, reply) => {
    const { id } = req.params as { id: string };
    const parsed = CommitDraftRequestSchema.parse(req.body || {});
    const result = await DraftReviewService.commitDraft(req.user!.userId, id, parsed, req.correlationId);
    return reply.send(result);
  });

  app.delete('/api/v1/multimodal/drafts/:id', { preHandler: [requireAuth] }, async (req, reply) => {
    const { id } = req.params as { id: string };
    const discarded = await DraftReviewService.discardDraft(req.user!.userId, id, req.correlationId);
    return reply.send({ draft: discarded });
  });

  // Wearable/device integrations are deferred per blueprint §27.2 — the ingestion
  // tables remain for GDPR export/purge coverage of any historically imported data.
  PrivacyOrchestrator.registerModule(new IntegrationsPrivacyContract());

  return app;
}
