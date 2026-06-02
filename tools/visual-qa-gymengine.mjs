import { chromium } from 'playwright';
import fs from 'node:fs/promises';
import path from 'node:path';

const rootDir = path.resolve(import.meta.dirname, '..');
const outDir = path.join(rootDir, 'screenshots', 'qa');
const apiBase = process.env.GYMENGINE_API_BASE ?? 'http://127.0.0.1:3017/api';
const webBase = process.env.GYMENGINE_WEB_BASE ?? 'http://127.0.0.1:5177';
const password = process.env.GYMENGINE_QA_PASSWORD ?? 'Gym12345';

function iso(date) {
  return new Date(date).toISOString();
}

async function jsonFetch(url, options = {}) {
  const response = await fetch(url, {
    ...options,
    headers: {
      'content-type': 'application/json',
      ...(options.headers ?? {}),
    },
  });
  const text = await response.text();
  let body = {};
  try {
    body = text ? JSON.parse(text) : {};
  } catch {
    body = { raw: text };
  }
  if (!response.ok) {
    throw new Error(`${response.status} ${response.statusText}: ${JSON.stringify(body)}`);
  }
  return body;
}

function exercise({
  id,
  name,
  primaryMuscle,
  bodyPart,
  equipment,
  exerciseType = 'weight_reps',
  imageUrl,
  videoUrl,
  sourceUrl,
}) {
  return {
    id,
    name,
    primaryMuscle,
    bodyPart,
    equipment,
    exerciseType,
    imageUrl,
    videoUrl,
    sourceUrl,
    createdAt: iso('2026-05-01T08:00:00Z'),
    syncStatus: 'synced',
  };
}

function session(id, startedAt, finishedAt, templateName, templateDayNumber) {
  return {
    id,
    startedAt: iso(startedAt),
    finishedAt: finishedAt ? iso(finishedAt) : null,
    templateName,
    templateDayNumber,
    syncStatus: 'synced',
  };
}

function set(id, sessionId, exerciseId, exerciseName, weightKg, reps, loggedAt) {
  return {
    id,
    sessionId,
    exerciseId,
    exerciseName,
    weightKg,
    reps,
    loggedAt: iso(loggedAt),
    syncStatus: 'synced',
  };
}

function buildSnapshot({ userId, email }) {
  const exercises = [
    exercise({
      id: 'barbell_full_squat',
      name: 'Barbell Full Squat',
      primaryMuscle: 'Quads',
      bodyPart: 'Quadriceps, Thighs',
      equipment: 'Barbell',
      imageUrl: 'https://apilyfta.com/static/GymvisualPNG/08781101-Barbell-Full-squat-(with-rack)_Thighs_small.png',
      videoUrl: 'https://apilyfta.com/static/GymvisualMP4/08781201-Barbell-Full-squat-(with-rack)_Thighs.mp4',
      sourceUrl: 'https://www.lyfta.app/exercise/barbell-full-squat--6xu',
    }),
    exercise({
      id: 'barbell_hip_thrust',
      name: 'Barbell Hip Thrust',
      primaryMuscle: 'Glutes',
      bodyPart: 'Hips',
      equipment: 'Barbell',
      imageUrl: 'https://apilyfta.com/static/GymvisualPNG/10611101-Barbell-Hip-Thrust_Hips_small.png',
      videoUrl: 'https://apilyfta.com/static/GymvisualMP4/10611201-Barbell-Hip-Thrust_Hips.mp4',
      sourceUrl: 'https://www.lyfta.app/exercise/barbell-hip-thrust--7t5',
    }),
    exercise({
      id: 'barbell_bench_press',
      name: 'Barbell Bench Press',
      primaryMuscle: 'Chest',
      bodyPart: 'Chest',
      equipment: 'Barbell',
      imageUrl: 'https://apilyfta.com/static/GymvisualPNG/24401101-Barbell-Bench-Press-(female)_Chest_small.png',
      videoUrl: 'https://apilyfta.com/static/GymvisualMP4/24401201-Barbell-Bench-Press-(female)_Chest.mp4',
      sourceUrl: 'https://www.lyfta.app/exercise/barbell-bench-press--7z1',
    }),
    exercise({
      id: 'pull_up_pull_up_1i',
      name: 'Pull-up',
      primaryMuscle: 'Back',
      bodyPart: 'Back',
      equipment: 'Body weight',
      imageUrl: 'https://apilyfta.com/static/GymvisualPNG/06521101-Pull-up_Back_small.png',
      videoUrl: 'https://apilyfta.com/static/GymvisualMP4/06521201-Pull-up_Back-FIX_.mp4',
      sourceUrl: 'https://www.lyfta.app/exercise/pull-up-1i',
    }),
    exercise({
      id: 'barbell_deadlift',
      name: 'Barbell Deadlift',
      primaryMuscle: 'Glutes',
      bodyPart: 'Thighs',
      equipment: 'Barbell',
      imageUrl: 'https://apilyfta.com/static/GymvisualPNG/22141101-Barbell-Deadlift-(female)_Hips_small.png',
      videoUrl: 'https://apilyfta.com/static/GymvisualMP4/22141201-Barbell-Deadlift-(female)_Hips_.mp4',
      sourceUrl: 'https://www.lyfta.app/exercise/barbell-deadlift--7sd',
    }),
    exercise({
      id: 'dumbbell_biceps_curl',
      name: 'Dumbbell Biceps Curl',
      primaryMuscle: 'Biceps',
      bodyPart: 'Upper Arms',
      equipment: 'Dumbbell',
      imageUrl: 'https://apilyfta.com/static/GymvisualPNG/02851101-Dumbbell-Biceps-Curl_Upper-Arms_small.png',
      videoUrl: 'https://apilyfta.com/static/GymvisualMP4/02851201-Dumbbell-Biceps-Curl_Upper-Arms.mp4',
      sourceUrl: 'https://www.lyfta.app/exercise/dumbbell-biceps-curl-84',
    }),
    exercise({
      id: 'cable_pushdown',
      name: 'Cable Pushdown',
      primaryMuscle: 'Triceps',
      bodyPart: 'Upper Arms',
      equipment: 'Cable',
      imageUrl: 'https://apilyfta.com/static/GymvisualPNG/02011101-Cable-Pushdown_Upper-Arms_small.png',
      videoUrl: 'https://apilyfta.com/static/GymvisualMP4/02011201-Cable-Pushdown_Upper-Arms.mp4',
      sourceUrl: 'https://www.lyfta.app/exercise/cable-pushdown-8p',
    }),
  ];

  const trainingDays = [
    {
      id: 'qa-day-1',
      dayOfWeek: 1,
      dayNumber: 1,
      customName: 'Legs + Glutes',
      restSeconds: 90,
      setTargetSeconds: 45,
      createdAt: iso('2026-05-01T08:00:00Z'),
      updatedAt: iso('2026-06-01T08:00:00Z'),
      syncStatus: 'synced',
    },
    {
      id: 'qa-day-2',
      dayOfWeek: 2,
      dayNumber: 2,
      customName: 'Push + Pull',
      restSeconds: 75,
      setTargetSeconds: 45,
      createdAt: iso('2026-05-01T08:00:00Z'),
      updatedAt: iso('2026-06-01T08:00:00Z'),
      syncStatus: 'synced',
    },
  ];

  const plannedExercises = [
    { id: 'qa-plan-1', dayId: 'qa-day-1', exerciseId: 'barbell_full_squat', sortOrder: 0, targetSets: 4, targetReps: 8, comment: 'Keep knees stable. Add 2.5 kg when all reps are clean.' },
    { id: 'qa-plan-2', dayId: 'qa-day-1', exerciseId: 'barbell_hip_thrust', sortOrder: 1, targetSets: 4, targetReps: 10, comment: 'Pause at lockout.' },
    { id: 'qa-plan-3', dayId: 'qa-day-1', exerciseId: 'barbell_deadlift', sortOrder: 2, targetSets: 3, targetReps: 5, comment: 'Heavy hinge, no rush.' },
    { id: 'qa-plan-4', dayId: 'qa-day-2', exerciseId: 'barbell_bench_press', sortOrder: 0, targetSets: 4, targetReps: 6, comment: 'Shoulders packed.' },
    { id: 'qa-plan-5', dayId: 'qa-day-2', exerciseId: 'pull_up_pull_up_1i', sortOrder: 1, targetSets: 4, targetReps: 8, comment: 'Full stretch each rep.' },
    { id: 'qa-plan-6', dayId: 'qa-day-2', exerciseId: 'dumbbell_biceps_curl', sortOrder: 2, targetSets: 3, targetReps: 12, comment: 'No swinging.' },
    { id: 'qa-plan-7', dayId: 'qa-day-2', exerciseId: 'cable_pushdown', sortOrder: 3, targetSets: 3, targetReps: 12, comment: 'Elbows fixed.' },
  ];

  const sessions = [
    session('qa-session-may-1', '2026-05-03T15:00:00Z', '2026-05-03T16:05:00Z', 'Legs + Glutes', 1),
    session('qa-session-may-2', '2026-05-05T15:10:00Z', '2026-05-05T16:00:00Z', 'Push + Pull', 2),
    session('qa-session-may-3', '2026-05-10T14:50:00Z', '2026-05-10T16:05:00Z', 'Legs + Glutes', 1),
    session('qa-session-jun-1', '2026-06-01T16:00:00Z', '2026-06-01T17:12:00Z', 'Legs + Glutes', 1),
    session('qa-session-jun-2', '2026-06-02T17:20:00Z', '2026-06-02T18:05:00Z', 'Push + Pull', 2),
  ];

  const sets = [
    set('qa-set-1', 'qa-session-may-1', 'barbell_full_squat', 'Barbell Full Squat', 70, 8, '2026-05-03T15:10:00Z'),
    set('qa-set-2', 'qa-session-may-1', 'barbell_full_squat', 'Barbell Full Squat', 72.5, 8, '2026-05-03T15:18:00Z'),
    set('qa-set-3', 'qa-session-may-1', 'barbell_hip_thrust', 'Barbell Hip Thrust', 90, 10, '2026-05-03T15:35:00Z'),
    set('qa-set-4', 'qa-session-may-1', 'barbell_deadlift', 'Barbell Deadlift', 95, 5, '2026-05-03T15:55:00Z'),
    set('qa-set-5', 'qa-session-may-2', 'barbell_bench_press', 'Barbell Bench Press', 42.5, 6, '2026-05-05T15:20:00Z'),
    set('qa-set-6', 'qa-session-may-2', 'pull_up_pull_up_1i', 'Pull-up', 0, 8, '2026-05-05T15:40:00Z'),
    set('qa-set-7', 'qa-session-may-2', 'dumbbell_biceps_curl', 'Dumbbell Biceps Curl', 12, 12, '2026-05-05T15:50:00Z'),
    set('qa-set-8', 'qa-session-may-2', 'cable_pushdown', 'Cable Pushdown', 27.5, 12, '2026-05-05T15:55:00Z'),
    set('qa-set-9', 'qa-session-may-3', 'barbell_full_squat', 'Barbell Full Squat', 75, 8, '2026-05-10T15:00:00Z'),
    set('qa-set-10', 'qa-session-may-3', 'barbell_full_squat', 'Barbell Full Squat', 77.5, 6, '2026-05-10T15:10:00Z'),
    set('qa-set-11', 'qa-session-may-3', 'barbell_hip_thrust', 'Barbell Hip Thrust', 100, 10, '2026-05-10T15:30:00Z'),
    set('qa-set-12', 'qa-session-may-3', 'barbell_deadlift', 'Barbell Deadlift', 105, 4, '2026-05-10T15:55:00Z'),
    set('qa-set-13', 'qa-session-jun-1', 'barbell_full_squat', 'Barbell Full Squat', 80, 7, '2026-06-01T16:10:00Z'),
    set('qa-set-14', 'qa-session-jun-1', 'barbell_full_squat', 'Barbell Full Squat', 82.5, 5, '2026-06-01T16:20:00Z'),
    set('qa-set-15', 'qa-session-jun-1', 'barbell_hip_thrust', 'Barbell Hip Thrust', 110, 8, '2026-06-01T16:42:00Z'),
    set('qa-set-16', 'qa-session-jun-1', 'barbell_deadlift', 'Barbell Deadlift', 110, 5, '2026-06-01T17:00:00Z'),
    set('qa-set-17', 'qa-session-jun-2', 'barbell_bench_press', 'Barbell Bench Press', 45, 6, '2026-06-02T17:30:00Z'),
    set('qa-set-18', 'qa-session-jun-2', 'pull_up_pull_up_1i', 'Pull-up', 0, 9, '2026-06-02T17:45:00Z'),
    set('qa-set-19', 'qa-session-jun-2', 'dumbbell_biceps_curl', 'Dumbbell Biceps Curl', 14, 10, '2026-06-02T17:55:00Z'),
    set('qa-set-20', 'qa-session-jun-2', 'cable_pushdown', 'Cable Pushdown', 30, 12, '2026-06-02T18:00:00Z'),
  ];

  return {
    schemaVersion: 13,
    exportedAt: new Date().toISOString(),
    profile: {
      displayName: 'QA Athlete',
      bodyWeightKg: 62.5,
      userId,
      email,
      authBaseUrl: apiBase,
      syncCode: userId,
      syncBaseUrl: apiBase,
    },
    exercises,
    trainingDays,
    plannedExercises,
    sessions,
    sets,
    progressPhotos: [],
  };
}

async function seedQaUser() {
  const email = `qa-${Date.now()}@gymengine.local`;
  const register = await jsonFetch(`${apiBase}/auth/register`, {
    method: 'POST',
    body: JSON.stringify({
      email,
      password,
      confirmPassword: password,
      name: 'QA Athlete',
    }),
  });
  if (!register.devCode) {
    throw new Error('No dev verification code returned. Configure SMTP or expose devCode for local QA.');
  }
  const verified = await jsonFetch(`${apiBase}/auth/register/verify`, {
    method: 'POST',
    body: JSON.stringify({ email, code: register.devCode }),
  });
  const token = verified.token;
  const userId = verified.user?.id;
  if (!token || !userId) {
    throw new Error(`Registration did not return token/user: ${JSON.stringify(verified)}`);
  }
  const snapshot = buildSnapshot({ userId, email });
  await jsonFetch(`${apiBase}/sync/me`, {
    method: 'PUT',
    headers: { authorization: `Bearer ${token}` },
    body: JSON.stringify(snapshot),
  });
  await fs.mkdir(path.join(rootDir, '.tmp'), { recursive: true });
  await fs.writeFile(
    path.join(rootDir, '.tmp', 'qa-user.json'),
    JSON.stringify({ email, password, userId, apiBase, webBase }, null, 2),
  );
  return { email, password, userId };
}

async function clickType(page, x, y, text) {
  await page.mouse.click(x, y);
  await page.waitForTimeout(150);
  const field = page.locator('input:not([type="submit"])').last();
  await field.fill(text, { timeout: 3000 });
  await page.waitForTimeout(100);
}

async function screenshot(page, name, options = {}) {
  await page.screenshot({
    path: path.join(outDir, name),
    fullPage: options.fullPage ?? false,
  });
}

async function runDesktopPass(user) {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({
    viewport: { width: 1280, height: 720 },
    deviceScaleFactor: 1,
  });
  const page = await context.newPage();
  await page.goto(`${webBase}/?v=qa-${Date.now()}`);
  await page.waitForTimeout(6000);
  await screenshot(page, 'desktop-auth.png');

  await clickType(page, 640, 384, user.email);
  await clickType(page, 640, 440, user.password);
  await page.mouse.click(640, 535);
  await page.waitForTimeout(5500);
  await screenshot(page, 'desktop-home.png');

  await page.mouse.click(565, 675);
  await page.waitForTimeout(2200);
  await screenshot(page, 'desktop-search.png');

  await page.mouse.click(640, 675);
  await page.waitForTimeout(2200);
  await screenshot(page, 'desktop-progress-overview.png', { fullPage: true });

  await page.mouse.click(553, 142);
  await page.waitForTimeout(1200);
  await screenshot(page, 'desktop-progress-exercises.png', { fullPage: true });

  await page.mouse.click(650, 142);
  await page.waitForTimeout(1200);
  await screenshot(page, 'desktop-progress-measurements.png', { fullPage: true });

  await page.mouse.click(800, 675);
  await page.waitForTimeout(1800);
  await screenshot(page, 'desktop-profile.png');
  await browser.close();
}

async function runMobilePass(user) {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({
    viewport: { width: 390, height: 844 },
    isMobile: true,
    hasTouch: true,
    deviceScaleFactor: 2,
  });
  const page = await context.newPage();
  await page.goto(`${webBase}/?v=qa-mobile-${Date.now()}`);
  await page.waitForTimeout(6000);
  await screenshot(page, 'mobile-auth.png');

  await clickType(page, 195, 446, user.email);
  await clickType(page, 195, 502, user.password);
  await page.mouse.click(195, 596);
  await page.waitForTimeout(5500);
  await screenshot(page, 'mobile-home.png');

  await page.mouse.click(250, 715);
  await page.waitForTimeout(2500);
  await screenshot(page, 'mobile-active-session.png');
  await page.mouse.click(32, 52);
  await page.waitForTimeout(1200);

  await page.mouse.click(145, 813);
  await page.waitForTimeout(2200);
  await screenshot(page, 'mobile-search.png');

  await page.mouse.click(245, 813);
  await page.waitForTimeout(2200);
  await screenshot(page, 'mobile-progress-overview.png', { fullPage: true });

  await page.mouse.click(137, 142);
  await page.waitForTimeout(1300);
  await screenshot(page, 'mobile-progress-exercises.png', { fullPage: true });

  await page.mouse.click(235, 142);
  await page.waitForTimeout(1300);
  await screenshot(page, 'mobile-progress-measurements.png', { fullPage: true });

  await page.mouse.click(340, 813);
  await page.waitForTimeout(1800);
  await screenshot(page, 'mobile-profile.png');
  await browser.close();
}

await fs.mkdir(outDir, { recursive: true });
const user = await seedQaUser();
await runDesktopPass(user);
await runMobilePass(user);

console.log(JSON.stringify({ outDir, user }, null, 2));
