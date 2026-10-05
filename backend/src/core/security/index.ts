import argon2 from 'argon2';
import crypto from 'crypto';
import { config } from '../../config/index.js';

export interface TokenPayload {
  userId: string;
  email: string;
  role: string;
}

export interface AuthTokens {
  accessToken: string;
  refreshToken: string;
  expiresInSeconds: number;
}

export async function hashPassword(password: string): Promise<string> {
  return argon2.hash(password, {
    type: argon2.argon2id,
    memoryCost: 65536, // 64 MB
    timeCost: 3,
    parallelism: 4
  });
}

export async function verifyPassword(hash: string, plain: string): Promise<boolean> {
  try {
    return await argon2.verify(hash, plain);
  } catch {
    return false;
  }
}

export function hashToken(token: string): string {
  return crypto.createHash('sha256').update(token).digest('hex');
}

export function generateSecureRandomToken(byteLength = 32): string {
  return crypto.randomBytes(byteLength).toString('hex');
}

// Simple deterministic JWT implementation using HMAC-SHA256
export function signJwt(payload: TokenPayload, secret: string, expiresInSeconds: number): string {
  const header = { alg: 'HS256', typ: 'JWT' };
  const now = Math.floor(Date.now() / 1000);
  const fullPayload = {
    ...payload,
    iat: now,
    exp: now + expiresInSeconds
  };

  const b64Header = Buffer.from(JSON.stringify(header)).toString('base64url');
  const b64Payload = Buffer.from(JSON.stringify(fullPayload)).toString('base64url');
  const signature = crypto
    .createHmac('sha256', secret)
    .update(`${b64Header}.${b64Payload}`)
    .digest('base64url');

  return `${b64Header}.${b64Payload}.${signature}`;
}

export function verifyJwt(token: string, secret: string): TokenPayload {
  const parts = token.split('.');
  if (parts.length !== 3) {
    throw new Error('Invalid JWT format');
  }

  const [b64Header, b64Payload, signature] = parts as [string, string, string];
  const expectedSig = crypto
    .createHmac('sha256', secret)
    .update(`${b64Header}.${b64Payload}`)
    .digest();

  let providedSig: Buffer;
  try {
    providedSig = Buffer.from(signature, 'base64url');
  } catch {
    throw new Error('Invalid JWT signature');
  }

  if (
    providedSig.length !== expectedSig.length ||
    !crypto.timingSafeEqual(providedSig, expectedSig)
  ) {
    throw new Error('Invalid JWT signature');
  }

  const payloadStr = Buffer.from(b64Payload, 'base64url').toString('utf8');
  const payload = JSON.parse(payloadStr) as TokenPayload & { exp: number };

  const now = Math.floor(Date.now() / 1000);
  if (payload.exp < now) {
    throw new Error('JWT token has expired');
  }

  return {
    userId: payload.userId,
    email: payload.email,
    role: payload.role
  };
}

export function generateTokenPair(payload: TokenPayload): AuthTokens {
  const ACCESS_TOKEN_TTL = 900; // 15 minutes
  const accessToken = signJwt(payload, config.JWT_ACCESS_SECRET, ACCESS_TOKEN_TTL);
  const refreshToken = generateSecureRandomToken(32);

  return {
    accessToken,
    refreshToken,
    expiresInSeconds: ACCESS_TOKEN_TTL
  };
}
