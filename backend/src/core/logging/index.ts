import pino from 'pino';
import { config } from '../../config/index.js';

/**
 * Sensitive fields that must NEVER appear in application logs.
 * Includes secrets, credentials, tokens, PII, and raw health biometric content (Blueprint §32 Invariant 13).
 */
const REDACTED_KEYS = [
  'authorization',
  'cookie',
  'password',
  'token',
  'refreshToken',
  'accessToken',
  'apiKey',
  'secret',
  'key',
  'jwt',
  'base64',
  'imageBase64',
  'bloodGlucose',
  'systolic',
  'diastolic',
  'weightKg',
  'heartRateBpm',
  'prompt',
  'message',
  'content',
  'observations',
  'measurements'
];

/**
 * Recursively sanitizes any object or payload before logging.
 */
export function sanitizeLogData(data: any): any {
  if (data === null || data === undefined) {
    return data;
  }
  if (typeof data !== 'object') {
    return data;
  }
  if (Array.isArray(data)) {
    return data.map(item => sanitizeLogData(item));
  }

  const sanitized: Record<string, any> = {};
  for (const [key, value] of Object.entries(data)) {
    const lowerKey = key.toLowerCase();
    const isSensitive = REDACTED_KEYS.some(redacted => lowerKey.includes(redacted.toLowerCase()));

    if (isSensitive) {
      sanitized[key] = '[REDACTED]';
    } else if (typeof value === 'object' && value !== null) {
      sanitized[key] = sanitizeLogData(value);
    } else {
      sanitized[key] = value;
    }
  }
  return sanitized;
}

/**
 * Production-ready structured JSON logger with automated redaction.
 */
export const logger = pino({
  level: config.LOG_LEVEL || 'info',
  formatters: {
    level: (label) => ({ level: label }),
  },
  redact: {
    paths: [
      'req.headers.authorization',
      'req.headers.cookie',
      '*.password',
      '*.refreshToken',
      '*.accessToken',
      '*.apiKey',
      '*.secret',
      '*.base64',
      '*.imageBase64'
    ],
    censor: '[REDACTED]'
  },
  timestamp: pino.stdTimeFunctions.isoTime
});

export const appLogger = {
  info: (msg: string, meta?: Record<string, any>) => logger.info(sanitizeLogData(meta || {}), msg),
  warn: (msg: string, meta?: Record<string, any>) => logger.warn(sanitizeLogData(meta || {}), msg),
  error: (msg: string, meta?: Record<string, any>) => logger.error(sanitizeLogData(meta || {}), msg),
  debug: (msg: string, meta?: Record<string, any>) => logger.debug(sanitizeLogData(meta || {}), msg)
};
