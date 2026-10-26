const memoryCache = new Map();
let redisClientPromise;

async function redisClient() {
  if (!process.env.REDIS_URL) return null;
  if (redisClientPromise) return redisClientPromise;

  redisClientPromise = import('redis')
    .then(async ({ createClient }) => {
      const client = createClient({ url: process.env.REDIS_URL });
      client.on('error', (err) => {
        console.warn('Redis cache error:', err.message);
      });
      await client.connect();
      return client;
    })
    .catch((err) => {
      console.warn('Redis cache unavailable, using memory cache:', err.message);
      return null;
    });

  return redisClientPromise;
}

export async function getCacheJson(key) {
  const redis = await redisClient();
  if (redis) {
    const value = await redis.get(key);
    return value ? JSON.parse(value) : null;
  }

  const entry = memoryCache.get(key);
  if (!entry) return null;
  if (entry.expiresAt <= Date.now()) {
    memoryCache.delete(key);
    return null;
  }
  return entry.value;
}

export async function setCacheJson(key, value, ttlSeconds = 300) {
  const redis = await redisClient();
  if (redis) {
    await redis.set(key, JSON.stringify(value), { EX: ttlSeconds });
    return;
  }

  memoryCache.set(key, {
    value,
    expiresAt: Date.now() + ttlSeconds * 1000,
  });
}

export async function clearCache(keys) {
  const normalized = Array.isArray(keys) ? keys : [keys];
  const redis = await redisClient();
  if (redis && normalized.length > 0) {
    await redis.del(normalized);
  }
  for (const key of normalized) {
    memoryCache.delete(key);
  }
}

export async function cachedJson(key, ttlSeconds, loader) {
  const cached = await getCacheJson(key);
  if (cached != null) return cached;
  const value = await loader();
  await setCacheJson(key, value, ttlSeconds);
  return value;
}
