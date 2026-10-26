import fs from 'fs/promises';
import path from 'path';
import { fileURLToPath } from 'url';

import express from 'express';
import { cachedJson } from '../lib/cache.js';

const router = express.Router();
const __dirname = path.dirname(fileURLToPath(import.meta.url));
const dataDir = path.resolve(__dirname, '../../data');
const panoramaFile = path.join(dataDir, 'panorama-scenes.json');
const publicCacheKey = 'panorama-scenes:public';

async function readPanoramaScenes() {
  try {
    const raw = await fs.readFile(panoramaFile, 'utf8');
    return JSON.parse(raw);
  } catch (err) {
    if (err.code === 'ENOENT') return [];
    throw err;
  }
}

router.get('/', async (_req, res, next) => {
  try {
    const scenes = await cachedJson(publicCacheKey, 60 * 30, async () => {
      const allScenes = await readPanoramaScenes();
      return allScenes.filter((scene) => scene.is_active !== false);
    });
    res.set('Cache-Control', 'public, max-age=300, stale-while-revalidate=1800');
    res.json(scenes);
  } catch (err) {
    next(err);
  }
});

export default router;

