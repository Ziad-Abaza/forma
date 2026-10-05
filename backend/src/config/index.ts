import { z } from 'zod';
import dotenv from 'dotenv';
import path from 'path';
import os from 'os';
import fs from 'fs';
import crypto from 'crypto';

// Load .env from backend directory first, then fallback to cwd or parent
dotenv.config({ path: path.resolve(__dirname, '../../.env') });
dotenv.config({ path: path.resolve(process.cwd(), '.env') });
dotenv.config({ path: path.resolve(process.cwd(), '../.env') });

const ENCRYPTION_KEY_HEX_PATTERN = /^[0-9a-fA-F]{64}$/;

const configSchema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().default(3000),
  HOST: z.string().optional(),
  LOCAL_SERVER: z.preprocess((val) => val === 'true' || val === true || val === '1', z.boolean()).default(false),
  DATABASE_URL: z.string().min(1).optional(),
  DATABASE_URL_TEST: z.string().min(1).optional(),
  DATABASE_URL_MIGRATIONS: z.string().min(1).optional(),
  JWT_ACCESS_SECRET: z.string().min(32).optional(),
  JWT_REFRESH_SECRET: z.string().min(32).optional(),
  ENCRYPTION_MASTER_KEY: z
    .string()
    .regex(ENCRYPTION_KEY_HEX_PATTERN, 'ENCRYPTION_MASTER_KEY must be a 64-character hex string (32 bytes)')
    .optional(),
  GEMINI_API_KEY: z.string().optional(),
  OPENAI_API_KEY: z.string().optional(),
  OPENAI_BASE_URL: z.string().url().optional(),
  SECONDARY_AI_BASE_URL: z.string().url().optional(),
  SECONDARY_AI_API_KEY: z.string().optional(),
  CORS_ORIGINS: z.string().optional(),
  LOG_LEVEL: z.enum(['fatal', 'error', 'warn', 'info', 'debug', 'trace']).default('info'),
  /** Access-token lifetime in seconds. Default 15 minutes. */
  JWT_ACCESS_TTL_SECONDS: z.coerce.number().int().positive().default(900),
  /** Refresh-token session lifetime in days. Default 30 days. */
  SESSION_TTL_DAYS: z.coerce.number().int().positive().default(30),
  /** Argon2id memory cost in KiB. Default 64 MiB. */
  ARGON2_MEMORY_COST_KIB: z.coerce.number().int().min(8192).default(65536),
  /** Argon2id iteration count. */
  ARGON2_TIME_COST: z.coerce.number().int().min(1).default(3),
  ARGON2_PARALLELISM: z.coerce.number().int().min(1).max(16).default(4)
});

type ParsedConfig = z.infer<typeof configSchema>;

export interface AppConfig extends Omit<ParsedConfig, 'JWT_ACCESS_SECRET' | 'JWT_REFRESH_SECRET' | 'ENCRYPTION_MASTER_KEY'> {
  JWT_ACCESS_SECRET: string;
  JWT_REFRESH_SECRET: string;
  ENCRYPTION_MASTER_KEY: string;
}

/**
 * Parses and validates environment configuration. Secret material has NO defaults:
 * outside test runs the process refuses to boot when required secrets are absent.
 * In NODE_ENV=test, missing secrets are replaced with ephemeral random values —
 * never with literals committed to source.
 */
export function parseConfig(env: NodeJS.ProcessEnv): AppConfig {
  const parsed = configSchema.safeParse(env);
  if (!parsed.success) {
    console.error('Configuration validation failed:', parsed.error.format());
    throw new Error('Invalid environment configuration');
  }

  const data = parsed.data;
  const isTest = data.NODE_ENV === 'test' || env.VITEST === 'true';

  const missingRequired: string[] = [];
  if (!isTest) {
    if (!data.DATABASE_URL) missingRequired.push('DATABASE_URL');
    if (!data.JWT_ACCESS_SECRET) missingRequired.push('JWT_ACCESS_SECRET');
    if (!data.JWT_REFRESH_SECRET) missingRequired.push('JWT_REFRESH_SECRET');
    if (!data.ENCRYPTION_MASTER_KEY) missingRequired.push('ENCRYPTION_MASTER_KEY');
  }
  if (missingRequired.length > 0) {
    throw new Error(
      `Missing required environment variables: ${missingRequired.join(', ')}. ` +
        `Provide them via the environment or .env (see .env.example).`
    );
  }

  return {
    ...data,
    JWT_ACCESS_SECRET: data.JWT_ACCESS_SECRET ?? crypto.randomBytes(32).toString('hex'),
    JWT_REFRESH_SECRET: data.JWT_REFRESH_SECRET ?? crypto.randomBytes(32).toString('hex'),
    ENCRYPTION_MASTER_KEY: data.ENCRYPTION_MASTER_KEY ?? crypto.randomBytes(32).toString('hex')
  };
}

export const config = parseConfig(process.env);

export function getDatabaseUrl(): string {
  const url = config.NODE_ENV === 'test' ? config.DATABASE_URL_TEST : config.DATABASE_URL;
  if (!url) {
    throw new Error(
      config.NODE_ENV === 'test'
        ? 'DATABASE_URL_TEST is required in test environment'
        : 'DATABASE_URL is required'
    );
  }
  return url;
}

/**
 * Detects the computer's primary local network IPv4 address (e.g. 192.168.x.x, 10.x.x.x).
 * Filters out internal loopback addresses and link-local (169.254.x.x) addresses.
 */
export function getLocalIpAddress(): string {
  const interfaces = os.networkInterfaces();
  for (const name of Object.keys(interfaces)) {
    for (const iface of interfaces[name] || []) {
      if (iface.family === 'IPv4' && !iface.internal && !iface.address.startsWith('169.254.')) {
        return iface.address;
      }
    }
  }
  return '127.0.0.1';
}

/**
 * Resolves the server bind host address.
 * When LOCAL_SERVER=true, binds to '0.0.0.0' to accept requests from external devices on the LAN.
 * When LOCAL_SERVER=false, binds to '127.0.0.1' (localhost).
 */
export function getEffectiveHost(envLocalServer: boolean = config.LOCAL_SERVER, envHost?: string): string {
  const hostVal = envHost !== undefined ? envHost : config.HOST;
  if (hostVal && hostVal.trim().length > 0) {
    return hostVal.trim();
  }
  return envLocalServer ? '0.0.0.0' : '127.0.0.1';
}

/**
 * Automatically synchronizes the mobile/.env configuration file with the computer's local IPv4 address.
 */
export function syncMobileEnv(localIp: string = getLocalIpAddress(), port: number = config.PORT): boolean {
  try {
    const candidatePaths = [
      path.resolve(process.cwd(), '../mobile/.env'),
      path.resolve(process.cwd(), 'mobile/.env'),
      path.resolve(__dirname, '../../../../mobile/.env'),
      path.resolve(__dirname, '../../../mobile/.env')
    ];

    let targetPath = candidatePaths.find(p => fs.existsSync(p));
    if (!targetPath) {
      const mobileDirCandidates = [
        path.resolve(process.cwd(), '../mobile'),
        path.resolve(process.cwd(), 'mobile'),
        path.resolve(__dirname, '../../../../mobile'),
        path.resolve(__dirname, '../../../mobile')
      ];
      const mobileDir = mobileDirCandidates.find(d => fs.existsSync(d));
      if (mobileDir) {
        targetPath = path.join(mobileDir, '.env');
      }
    }

    if (!targetPath) {
      return false;
    }

    const newBaseUrl = `http://${localIp}:${port}`;
    let content = '';

    if (fs.existsSync(targetPath)) {
      content = fs.readFileSync(targetPath, 'utf8');

      if (/^API_BASE_URL=.*$/m.test(content)) {
        content = content.replace(/^API_BASE_URL=.*$/m, `API_BASE_URL=${newBaseUrl}`);
      } else {
        content += `\nAPI_BASE_URL=${newBaseUrl}`;
      }

      if (/^LOCAL_SERVER=.*$/m.test(content)) {
        content = content.replace(/^LOCAL_SERVER=.*$/m, `LOCAL_SERVER=true`);
      } else {
        content += `\nLOCAL_SERVER=true`;
      }

      if (/^LOCAL_IP=.*$/m.test(content)) {
        content = content.replace(/^LOCAL_IP=.*$/m, `LOCAL_IP=${localIp}`);
      } else {
        content += `\nLOCAL_IP=${localIp}`;
      }
    } else {
      content = [
        '# ==============================================================================',
        '# Forma Mobile Local Environment Configuration',
        '# ==============================================================================',
        `API_BASE_URL=${newBaseUrl}`,
        'ENVIRONMENT=development',
        'API_TIMEOUT_MS=15000',
        'ENABLE_ANALYTICS_LOGS=false',
        'LOCAL_SERVER=true',
        `LOCAL_IP=${localIp}\n`
      ].join('\n');
    }

    fs.writeFileSync(targetPath, content.trim() + '\n', 'utf8');
    console.log(`[LOCAL SERVER] Auto-synced mobile/.env with local IP: ${newBaseUrl}`);
    return true;
  } catch (err) {
    console.warn(`[LOCAL SERVER] Could not auto-sync mobile/.env:`, err);
    return false;
  }
}
