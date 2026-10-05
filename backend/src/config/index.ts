import { z } from 'zod';
import dotenv from 'dotenv';
import path from 'path';
import os from 'os';
import fs from 'fs';

// Load .env from backend directory first, then fallback to cwd or parent
dotenv.config({ path: path.resolve(__dirname, '../../.env') });
dotenv.config({ path: path.resolve(process.cwd(), '.env') });
dotenv.config({ path: path.resolve(process.cwd(), '../.env') });

const configSchema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().default(3000),
  HOST: z.string().optional(),
  LOCAL_SERVER: z.preprocess((val) => val === 'true' || val === true || val === '1', z.boolean()).default(false),
  DATABASE_URL: z.string().default('postgresql://forma_app:forma_secure_app_role_pw@localhost:5432/forma_dev'),
  DATABASE_URL_TEST: z.string().default('postgresql://forma_app:forma_secure_app_role_pw@localhost:5432/forma_test'),
  JWT_ACCESS_SECRET: z.string().min(16).default('forma_dev_access_token_secret_minimum_32_characters!'),
  JWT_REFRESH_SECRET: z.string().min(16).default('forma_dev_refresh_token_secret_minimum_32_characters!'),
  GEMINI_API_KEY: z.string().optional(),
  AI_PRIMARY_MODEL: z.string().default('gemini-3.8-flash'),
  LOG_LEVEL: z.enum(['fatal', 'error', 'warn', 'info', 'debug', 'trace']).default('info')
});

const parsed = configSchema.safeParse(process.env);
if (!parsed.success) {
  console.error('Configuration validation failed:', parsed.error.format());
  throw new Error('Invalid environment configuration');
}

export const config = parsed.data;

export function getDatabaseUrl(): string {
  if (config.NODE_ENV === 'test') {
    return process.env['DATABASE_URL_TEST'] || config.DATABASE_URL_TEST;
  }
  return process.env['DATABASE_URL'] || config.DATABASE_URL;
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
