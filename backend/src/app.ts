import fastify, { type FastifyInstance, type FastifyRequest, type FastifyReply } from 'fastify';
import cors from '@fastify/cors';
import crypto from 'crypto';
import { config } from './config/index.js';
import { verifyJwt } from './core/security/index.js';
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

export interface AuthenticatedUser {
  userId: string;
  email: string;
  role: string;
}

declare module 'fastify' {
  interface FastifyRequest {
    user?: AuthenticatedUser;
    correlationId: string;
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

  // Middleware: Attach correlation ID to every request
  app.addHook('onRequest', async (req: FastifyRequest) => {
    req.correlationId = (req.headers['x-correlation-id'] as string) || crypto.randomUUID();
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
    reply.status(statusCode).send({
      error: error.message || 'An unexpected error occurred',
      correlationId: req.correlationId
    });
  });

  // Healthcheck route
  app.get('/health', async () => {
    return { status: 'healthy', timestamp: new Date().toISOString() };
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

  return app;
}
