import { syncMobileEnv, getLocalIpAddress, config } from '../src/config/index.js';

const localIp = getLocalIpAddress();
console.log(`[Forma] Detected local network IPv4: ${localIp}`);
const success = syncMobileEnv(localIp, config.PORT);
if (success) {
  console.log(`[Forma] Successfully updated mobile/.env with API_BASE_URL=http://${localIp}:${config.PORT}`);
} else {
  console.error('[Forma] Failed to find or update mobile/.env');
  process.exit(1);
}
