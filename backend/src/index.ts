import { buildApp } from './app.js';
import { config } from './config/index.js';
import { runMigrations } from './core/database/migrate.js';

async function startServer(): Promise<void> {
  try {
    console.log(`Starting Forma Backend service in ${config.NODE_ENV} mode...`);

    // Run database migrations on startup
    await runMigrations();

    const app = buildApp();
    const address = await app.listen({ port: config.PORT, host: '0.0.0.0' });
    console.log(`Forma Backend listening on ${address}`);
  } catch (err) {
    console.error('Failed to start server:', err);
    process.exit(1);
  }
}

startServer();
