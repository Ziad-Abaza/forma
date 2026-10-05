# ==============================================================================
# Forma Backend - Multi-Stage Production Containerfile
# Hardened, non-root, PID-1 supervised production build
# ==============================================================================

# --- Stage 1: Build Environment ---
FROM node:22-alpine AS builder

WORKDIR /app

# Copy dependency manifests
COPY package.json tsconfig.json ./

# Install all dependencies (including devDependencies required for compilation)
RUN npm install --no-audit --no-fund

# Copy source code and build scripts
COPY src/ ./src/
COPY scripts/ ./scripts/

# Compile TypeScript and copy migrations into dist/
RUN npm run build

# --- Stage 2: Hardened Production Runtime ---
FROM node:22-alpine AS runner

# Install dumb-init for robust PID 1 signal management (SIGTERM/SIGINT propagation)
RUN apk add --no-cache dumb-init wget

# Create non-root system group and user
RUN addgroup -S -g 10001 forma && \
    adduser -S -u 10001 -G forma forma

WORKDIR /app

# Copy package manifest
COPY package.json ./

# Install production runtime dependencies strictly
RUN npm install --omit=dev --no-audit --no-fund && \
    npm cache clean --force

# Copy compiled artifacts from builder stage with proper ownership
COPY --from=builder --chown=forma:forma /app/dist ./dist

# Create logs directory with non-root ownership
RUN mkdir -p /app/logs && chown -R forma:forma /app

# Switch to non-root execution
USER forma

# Runtime environment defaults
ENV NODE_ENV=production \
    PORT=3000 \
    LOG_LEVEL=info

EXPOSE 3000

# Container liveness & readiness health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000/health || exit 1

ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "dist/index.js"]
