import { buildApp } from './app.js';
import { config, getEffectiveHost, getLocalIpAddress, syncMobileEnv } from './config/index.js';
import { runMigrations } from './core/database/migrate.js';

async function startServer(): Promise<void> {
  try {
    console.log(`Starting Forma Backend service in ${config.NODE_ENV} mode...`);

    // Run database migrations on startup
    await runMigrations();

    const app = buildApp();
    const host = getEffectiveHost();
    const address = await app.listen({ port: config.PORT, host });
    console.log(`Forma Backend listening on ${address}`);

    if (config.LOCAL_SERVER) {
      const localIp = getLocalIpAddress();
      console.log(`================================================================`);
      console.log(`[LOCAL SERVER MODE ACTIVATED] (LOCAL_SERVER=true)`);
      console.log(`  Bound Interface:    ${host} (Listening for network devices)`);
      console.log(`  Local Network IP:   ${localIp}`);
      console.log(`  API Base URL:       http://${localIp}:${config.PORT}`);
      console.log(`  Health Probe:       http://${localIp}:${config.PORT}/health`);
      console.log(`  Physical Devices:   Connected to the same Wi-Fi can now communicate directly.`);
      console.log(`================================================================`);

      syncMobileEnv(localIp, config.PORT);
    }
  } catch (err) {
    console.error('Failed to start server:', err);
    process.exit(1);
  }
}

startServer();

