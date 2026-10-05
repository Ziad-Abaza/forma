import fastify, { type FastifyInstance, type FastifyRequest, type FastifyReply } from 'fastify';
import cors from '@fastify/cors';
import crypto from 'crypto';
import { config } from './config/index.js';
import { verifyJwt } from './core/security/index.js';
import { checkDatabaseHealth } from './core/database/index.js';
import { appLogger } from './core/logging/index.js';
import { IdentityService } from './modules/identity/service.js';
import { RegisterRequestSchema, LoginRequestSchema, RefreshTokenRequestSchema } from './modules/identity/contracts.js';
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
import { CreateGoalRequestSchema, UpdateGoalVersionRequestSchema } from './modules/goals/contracts.js';
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
import {
  IntegrationSyncService,
  IntegrationsPrivacyContract,
  SyncBatchRequestSchema,
  type IntegrationProvider
} from './modules/integrations/index.js';

export interface AuthenticatedUser {
  userId: string;
  email: string;
  role: string;
}

declare module 'fastify' {
  interface FastifyRequest {
    user?: AuthenticatedUser;
    correlationId: string;
    startTime: number;
  }
}

export function buildApp(): FastifyInstance {
  const app = fastify({
    logger: false // Logging handled by structured sanitized logger
  });

  // Enable CORS
  app.register(cors, {
    origin: true,
    credentials: true
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

    if (parsed.stream) {
      reply.raw.setHeader('Content-Type', 'text/event-stream');
      reply.raw.setHeader('Cache-Control', 'no-cache');
      reply.raw.setHeader('Connection', 'keep-alive');
      reply.raw.setHeader('Access-Control-Allow-Origin', '*');

      try {
        for await (const event of assistantOrchestrator.chatStream(userId, parsed, req.correlationId)) {
          reply.raw.write(`event: ${event.event}\ndata: ${JSON.stringify(event.data)}\n\n`);
        }
      } catch (err: any) {
        reply.raw.write(`event: error\ndata: ${JSON.stringify({ error: err.message })}\n\n`);
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

  // --- Integrations & Sync Routes (Blueprint §28.1) ---
  PrivacyOrchestrator.registerModule(new IntegrationsPrivacyContract());

  app.get('/api/v1/integrations/connections', { preHandler: [requireAuth] }, async (req, reply) => {
    const connections = await IntegrationSyncService.getConnections(req.user!.userId);
    return reply.send({ connections });
  });

  app.post('/api/v1/integrations/connect', { preHandler: [requireAuth] }, async (req, reply) => {
    const { provider, scopes, metadata } = req.body as {
      provider: IntegrationProvider;
      scopes?: string[];
      metadata?: Record<string, unknown>;
    };
    const connection = await IntegrationSyncService.connectProvider(req.user!.userId, provider, scopes, metadata);
    return reply.status(201).send({ connection });
  });

  app.post('/api/v1/integrations/disconnect', { preHandler: [requireAuth] }, async (req, reply) => {
    const { provider } = req.body as { provider: IntegrationProvider };
    await IntegrationSyncService.disconnectProvider(req.user!.userId, provider);
    return reply.send({ success: true });
  });

  app.post('/api/v1/integrations/sync', { preHandler: [requireAuth] }, async (req, reply) => {
    const parsed = SyncBatchRequestSchema.parse(req.body);
    const result = await IntegrationSyncService.ingestBatch(req.user!.userId, parsed, req.correlationId);
    return reply.send(result);
  });

  return app;
}
