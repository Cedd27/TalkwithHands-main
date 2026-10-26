import fs from 'fs/promises';
import path from 'path';
import { fileURLToPath } from 'url';
import { randomUUID } from 'crypto';

import express from 'express';
import { cachedJson, clearCache } from '../lib/cache.js';

const router = express.Router();
const __dirname = path.dirname(fileURLToPath(import.meta.url));
const dataDir = path.resolve(__dirname, '../../data');
const basicWordFile = path.join(dataDir, 'basic-words.json');
const publicCacheKey = 'basic-words:public';

async function readBasicWords() {
  try {
    const raw = await fs.readFile(basicWordFile, 'utf8');
    return JSON.parse(raw);
  } catch (err) {
    if (err.code === 'ENOENT') return [];
    throw err;
  }
}

async function writeBasicWords(words) {
  await fs.mkdir(dataDir, { recursive: true });
  await fs.writeFile(basicWordFile, JSON.stringify(words, null, 2));
  await clearCache(publicCacheKey);
}

function validateNewBasicWord(payload) {
  const key = String(payload.key || '').trim();
  const title = String(payload.title || '').trim();
  const category = String(payload.category || '').trim();
  const hasVideo = [
    payload.video_asset,
    payload.video_url,
    payload.front_video_url,
    payload.left_video_url,
    payload.right_video_url,
  ].some((value) => String(value || '').trim().length > 0);

  if (!/^[a-zA-Z0-9_-]+$/.test(key)) {
    return 'Basic word key may only contain letters, numbers, hyphens, or underscores.';
  }
  if (!title || !category) return 'Title and category are required.';
  if (!hasVideo) return 'Add at least one sign video before saving.';
  return null;
}

router.get('/', async (_req, res, next) => {
  try {
    const basicWords = await cachedJson(publicCacheKey, 60 * 30, async () => {
      const allWords = await readBasicWords();
      return allWords.filter((word) => word.is_active !== false);
    });
    res.set('Cache-Control', 'public, max-age=300, stale-while-revalidate=1800');
    res.json(basicWords);
  } catch (err) {
    next(err);
  }
});

router.get('/admin', async (_req, res, next) => {
  try {
    res.json(await readBasicWords());
  } catch (err) {
    next(err);
  }
});

router.post('/', async (req, res, next) => {
  try {
    const validationError = validateNewBasicWord(req.body || {});
    if (validationError) return res.status(400).json({ message: validationError });
    const basicWords = await readBasicWords();
    const key = String(req.body.key).trim().toLowerCase();
    if (basicWords.some((word) => String(word.key || '').toLowerCase() === key)) {
      return res.status(409).json({ message: 'A basic word with this key already exists.' });
    }
    const word = {
      id: randomUUID(),
      is_active: true,
      ...req.body,
      key,
    };
    basicWords.push(word);
    await writeBasicWords(basicWords);
    res.status(201).json(word);
  } catch (err) {
    next(err);
  }
});

router.patch('/:id', async (req, res, next) => {
  try {
    const basicWords = await readBasicWords();
    const index = basicWords.findIndex((word) => word.id === req.params.id);
    if (index === -1) {
      return res.status(404).json({ message: 'Basic word not found.' });
    }
    basicWords[index] = { ...basicWords[index], ...req.body };
    await writeBasicWords(basicWords);
    res.json(basicWords[index]);
  } catch (err) {
    next(err);
  }
});

router.delete('/:id', async (req, res, next) => {
  try {
    const basicWords = await readBasicWords();
    const index = basicWords.findIndex((word) => word.id === req.params.id);
    if (index === -1) {
      return res.status(404).json({ message: 'Basic word not found.' });
    }
    basicWords.splice(index, 1);
    await writeBasicWords(basicWords);
    res.status(204).end();
  } catch (err) {
    next(err);
  }
});

export default router;

