import { z } from 'zod';
import dotenv from 'dotenv';
import path from 'path';

// Load .env from backend directory first, then fallback to cwd or parent
dotenv.config({ path: path.resolve(__dirname, '../../.env') });
dotenv.config({ path: path.resolve(process.cwd(), '.env') });
dotenv.config({ path: path.resolve(process.cwd(), '../.env') });

const configSchema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().default(3000),
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
