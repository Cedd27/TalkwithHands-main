import fs from 'fs/promises';
import path from 'path';
import { fileURLToPath } from 'url';

import express from 'express';
import mongoose from 'mongoose';

import User from '../models/User.js';

const router = express.Router();
const __dirname = path.dirname(fileURLToPath(import.meta.url));
const dataDir = path.resolve(__dirname, '../../data');
const localUsersFile = path.join(dataDir, 'users.json');

function isMongoReady() {
  return process.env.USE_LOCAL_STORE !== 'true' && mongoose.connection.readyState === 1;
}

async function readUsers() {
  if (isMongoReady()) {
    return User.find({}).lean();
  }

  try {
    const raw = await fs.readFile(localUsersFile, 'utf8');
    return JSON.parse(raw);
  } catch (err) {
    if (err.code === 'ENOENT') return [];
    throw err;
  }
}

function countBy(users, labelFor) {
  const counts = new Map();
  for (const user of users) {
    const label = labelFor(user);
    counts.set(label, (counts.get(label) || 0) + 1);
  }
  return [...counts.entries()].map(([label, count]) => ({ label, count }));
}

function userDate(user) {
  return new Date(user.createdAt || user.created_at || user.updatedAt || Date.now());
}

function ageLabel(user) {
  const age = Number(user.age);
  if (!Number.isFinite(age) || age <= 0) return 'Unknown';
  if (age <= 12) return '0-12';
  if (age <= 17) return '13-17';
  if (age <= 24) return '18-24';
  if (age <= 34) return '25-34';
  return '35+';
}

function usageLabel(user) {
  const seconds = Number(user.progress?.seconds_spent || 0);
  if (seconds <= 0) return 'No activity';
  if (seconds < 60 * 10) return 'Light';
  if (seconds < 60 * 60) return 'Active';
  return 'Power';
}

function monthlyUsers(users) {
  const formatter = new Intl.DateTimeFormat('en', { month: 'short' });
  const counts = new Map();
  for (const user of users) {
    const date = userDate(user);
    if (Number.isNaN(date.getTime())) continue;
    const key = `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}`;
    counts.set(key, (counts.get(key) || 0) + 1);
  }
  return [...counts.entries()]
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([key, count]) => {
      const [year, month] = key.split('-').map(Number);
      return {
        key,
        label: `${formatter.format(new Date(year, month - 1, 1))} ${year}`,
        count,
      };
    });
}

router.get('/analytics', async (_req, res, next) => {
  try {
    const users = await readUsers();
    const reviews = users
      .filter((user) => Number(user.app_feedback?.rating || 0) > 0)
      .map((user) => ({
        id: String(user.id || user._id || ''),
        name: user.username || '',
        email: user.email || '',
        photo_url: user.photo_url || '',
        rating: Number(user.app_feedback?.rating || 0),
        review: user.app_feedback?.review || '',
        date: user.app_feedback?.updated_at || user.updatedAt || user.createdAt || null,
      }));

    const ratingTotal = reviews.reduce((sum, review) => sum + review.rating, 0);

    res.json({
      summary: {
        total_users: users.length,
        average_rating: reviews.length ? ratingTotal / reviews.length : 0,
        rating_count: reviews.length,
      },
      monthly_users: monthlyUsers(users),
      sex_counts: countBy(users, (user) => user.sex || 'Unspecified'),
      age_counts: countBy(users, ageLabel),
      usage_counts: countBy(users, usageLabel),
      users: users.map((user) => ({
        id: String(user.id || user._id || ''),
        name: user.username || '',
        email: user.email || '',
        address: user.address || '',
        phone: user.contact_number || '',
        sex: user.sex || '',
        age: user.age ?? null,
        date: user.createdAt || user.created_at || null,
        stars: Number(user.stars || 0),
        coins: Number(user.coins || 0),
      })),
      reviews,
    });
  } catch (err) {
    next(err);
  }
});

export default router;
