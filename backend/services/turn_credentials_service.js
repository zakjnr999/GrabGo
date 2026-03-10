const axios = require('axios');
const cache = require('../utils/cache');
const { createScopedLogger } = require('../utils/logger');
const console = createScopedLogger('turn_credentials_service');

const CACHE_KEY = 'grabgo:webrtc:turn-credentials';
const CACHE_TTL_SECONDS = 60 * 5;

const DEFAULT_ICE_SERVERS = [
  { urls: 'stun:stun.l.google.com:19302' },
  { urls: 'stun:stun1.l.google.com:19302' },
];

const normalizeIceServers = (payload) => {
  if (!Array.isArray(payload)) return [];

  return payload
    .filter((server) => server && typeof server === 'object')
    .map((server) => {
      const normalized = {
        urls: server.urls,
      };

      if (typeof server.username === 'string' && server.username.trim()) {
        normalized.username = server.username;
      }

      if (typeof server.credential === 'string' && server.credential.trim()) {
        normalized.credential = server.credential;
      }

      return normalized;
    })
    .filter((server) => {
      if (Array.isArray(server.urls)) {
        return server.urls.length > 0;
      }

      return typeof server.urls === 'string' && server.urls.trim().length > 0;
    });
};

const getFallbackCredentials = (source = 'stun_fallback') => ({
  iceServers: DEFAULT_ICE_SERVERS,
  source,
  expiresInSeconds: CACHE_TTL_SECONDS,
  fetchedAt: new Date().toISOString(),
});

const getTurnCredentials = async () => {
  const cached = await cache.get(CACHE_KEY);
  if (cached && Array.isArray(cached.iceServers) && cached.iceServers.length > 0) {
    return cached;
  }

  const providerUrl = process.env.METERED_TURN_CREDENTIALS_URL || process.env.TURN_CREDENTIALS_URL;
  if (!providerUrl) {
    return getFallbackCredentials('missing_provider_url');
  }

  try {
    const response = await axios.get(providerUrl, {
      timeout: 5000,
      validateStatus: (status) => status >= 200 && status < 500,
    });

    if (response.status !== 200) {
      console.warn(`[WebRTC] TURN credential provider responded with status ${response.status}`);
      return getFallbackCredentials('provider_non_200');
    }

    const iceServers = normalizeIceServers(response.data);
    if (iceServers.length === 0) {
      console.warn('[WebRTC] TURN credential provider returned invalid/empty ICE server list');
      return getFallbackCredentials('provider_invalid_payload');
    }

    const payload = {
      iceServers,
      source: 'provider',
      expiresInSeconds: CACHE_TTL_SECONDS,
      fetchedAt: new Date().toISOString(),
    };

    await cache.set(CACHE_KEY, payload, CACHE_TTL_SECONDS);
    return payload;
  } catch (error) {
    console.error('[WebRTC] Failed to fetch TURN credentials:', error.message);
    return getFallbackCredentials('provider_fetch_error');
  }
};

module.exports = {
  getTurnCredentials,
  getFallbackCredentials,
};
