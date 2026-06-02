import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import path from 'node:path';

const root = process.cwd();
const cacheDir = path.join(root, '.tmp', 'lyfta');
const jsonDir = path.join(cacheDir, 'exercise-json');
const outPath = path.join(
  root,
  'apps',
  'mobile',
  'lib',
  'data',
  'catalog',
  'lyfta_exercise_catalog.dart',
);
const userAgent = 'GymEngine educational crawler; portfolio app; permission granted by project owner';

const args = new Map(
  process.argv.slice(2).map((arg) => {
    const [key, value = 'true'] = arg.replace(/^--/, '').split('=');
    return [key, value];
  }),
);
const limit = Number(args.get('limit') ?? 0);
const concurrency = Math.max(1, Number(args.get('concurrency') ?? 8));
const refresh = args.has('refresh');

await mkdir(cacheDir, { recursive: true });
await mkdir(jsonDir, { recursive: true });
await mkdir(path.dirname(outPath), { recursive: true });

async function fetchText(url, attempts = 4) {
  for (let attempt = 1; attempt <= attempts; attempt += 1) {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 90000);
    try {
      const response = await fetch(url, {
        headers: { 'user-agent': userAgent },
        signal: controller.signal,
      });
      clearTimeout(timeout);
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
      }
      return await response.text();
    } catch (error) {
      clearTimeout(timeout);
      if (attempt === attempts) {
        throw error;
      }
      await sleep(attempt * 3500);
    }
  }
  throw new Error(`Failed to fetch ${url}`);
}

async function readCached(url, file, attempts = 4) {
  if (!refresh && existsSync(file)) {
    return readFile(file, 'utf8');
  }
  const text = await fetchText(url, attempts);
  await writeFile(file, text, 'utf8');
  return text;
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function decodeXml(value) {
  return value
    .replaceAll('&amp;', '&')
    .replaceAll('&quot;', '"')
    .replaceAll('&apos;', "'")
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>');
}

function slugFromUrl(url) {
  return new URL(url).pathname.split('/').filter(Boolean).pop();
}

function normalizeId(name, slug, used) {
  const base = name
    .toLowerCase()
    .normalize('NFKD')
    .replace(/[^\w\s-]/g, '')
    .replace(/\s+/g, '_')
    .replace(/-+/g, '_')
    .replace(/_+/g, '_')
    .replace(/^_|_$/g, '');
  const fallback = slug
    .replace(/-[a-z0-9]{1,3}$/i, '')
    .replace(/[^\w]+/g, '_')
    .replace(/^_|_$/g, '');
  let id = base || fallback || `lyfta_${used.size + 1}`;
  if (used.has(id)) {
    const suffix = slug.replace(/[^\w]+/g, '_').replace(/^_|_$/g, '');
    id = `${id}_${suffix}`;
  }
  while (used.has(id)) {
    id = `${id}_${used.size + 1}`;
  }
  used.add(id);
  return id;
}

function primaryMuscle(bodyParts, name, imageUrl) {
  const normalizedName = name.toLowerCase();
  const body = bodyParts.join(' ').toLowerCase();
  const image = String(imageUrl ?? '')
    .toLowerCase()
    .replaceAll('-', ' ')
    .replaceAll('_', ' ');
  const text = `${normalizedName} ${body} ${image}`;

  const has = (...patterns) => patterns.some((pattern) => text.includes(pattern));
  const nameHas = (...patterns) => patterns.some((pattern) => normalizedName.includes(pattern));

  if (nameHas('tricep', 'pushdown', 'skull crusher', 'french press', 'close grip')) {
    return 'Triceps';
  }
  if (
    nameHas('bicep', 'preacher', 'hammer curl', 'concentration curl', 'spider curl') ||
    (nameHas('curl') && has('upper arms', 'biceps'))
  ) {
    return 'Biceps';
  }
  if (
    nameHas('calf') ||
    has('lower legs', 'calves') ||
    nameHas('tibialis')
  ) {
    return 'Calves';
  }
  if (has('forearms') || nameHas('wrist', 'forearm', 'finger curl')) {
    return 'Forearms';
  }
  if (has('neck') || nameHas('neck')) {
    return 'Neck';
  }
  if (
    nameHas('crunch', 'sit up', 'sit-up', 'plank', 'twist', 'oblique', 'ab ', 'abs', 'v up', 'v-up', 'side bend') ||
    has('waist')
  ) {
    return 'Core';
  }
  if (
    nameHas('glute', 'hip thrust', 'bridge', 'kickback', 'abduction', 'adduction', 'frog pump') ||
    has('hips')
  ) {
    return 'Glutes';
  }
  if (
    nameHas('hamstring', 'leg curl', 'nordic', 'romanian', 'stiff leg', 'straight leg deadlift') ||
    nameHas('good morning')
  ) {
    return 'Hamstrings';
  }
  if (nameHas('deadlift', 'rack pull', 'hyperextension', 'back extension')) {
    return 'Posterior';
  }
  if (
    nameHas('squat', 'lunge', 'leg press', 'leg extension', 'step up', 'step-up', 'jump box', 'box jump', 'sissy') ||
    has('upper legs', 'thigh', 'plyometrics')
  ) {
    return 'Quads';
  }
  if (
    nameHas('shoulder', 'deltoid', 'delt', 'lateral raise', 'front raise', 'rear fly', 'rear delt', 'arnold', 'military press', 'overhead press', 'upright row') ||
    has('shoulders')
  ) {
    return 'Shoulders';
  }
  if (
    nameHas('bench press', 'chest press', 'pec', 'chest fly', 'push up', 'push-up', 'dip') ||
    has('chest')
  ) {
    return 'Chest';
  }
  if (
    nameHas('row', 'pulldown', 'pull up', 'pull-up', 'chin up', 'chin-up', 'lat ', 'shrug', 'back lever') ||
    has('back')
  ) {
    return 'Back';
  }
  if (has('cardio')) {
    return 'Core';
  }
  return 'Custom';
}

function cleanString(value) {
  if (value == null) return '';
  return String(value).replace(/^"+|"+$/g, '').trim();
}

function asList(value) {
  return Array.isArray(value) ? value.map(cleanString).filter(Boolean) : [];
}

function dartString(value) {
  return `'${String(value ?? '').replaceAll('\\', '\\\\').replaceAll("'", "\\'").replaceAll('\n', ' ')}'`;
}

async function discoverUrls() {
  const sitemapIndex = await readCached(
    'https://www.lyfta.app/sitemap.xml',
    path.join(cacheDir, 'sitemap.xml'),
  );
  const sitemapUrls = [
    ...sitemapIndex.matchAll(/<loc>(https:\/\/www\.lyfta\.app\/sitemaps\/sitemap\d+\.xml)<\/loc>/g),
  ].map((match) => decodeXml(match[1]));

  const urls = new Set();
  for (const sitemapUrl of sitemapUrls) {
    const file = path.join(cacheDir, path.basename(sitemapUrl));
    try {
      const xml = await readCached(sitemapUrl, file);
      for (const match of xml.matchAll(/<loc>(https:\/\/www\.lyfta\.app\/exercise[^<]+)<\/loc>/g)) {
        urls.add(decodeXml(match[1]));
      }
      console.log(`sitemap ${path.basename(sitemapUrl)} -> ${urls.size} exercise urls`);
    } catch (error) {
      console.log(`skip ${sitemapUrl}: ${error.message}`);
    }
  }
  return [...urls].sort();
}

async function discoverBuildId(sampleUrl) {
  const sampleHtml = await readCached(sampleUrl, path.join(cacheDir, `${slugFromUrl(sampleUrl)}.html`));
  const nextMatch = sampleHtml.match(
    /<script id="__NEXT_DATA__" type="application\/json">([\s\S]*?)<\/script>/,
  );
  if (!nextMatch) {
    throw new Error('Cannot find Next.js build id');
  }
  return JSON.parse(nextMatch[1]).buildId;
}

async function scrapeExercise(url, buildId, usedIds) {
  const slug = slugFromUrl(url);
  const file = path.join(jsonDir, `${slug}.json`);
  const jsonUrl = `https://www.lyfta.app/_next/data/${buildId}/exercise/${slug}.json`;
  const text = await readCached(jsonUrl, file);
  const data = JSON.parse(text).pageProps?.firstData;
  if (!data?.name) {
    throw new Error(`Missing firstData for ${slug}`);
  }
  const name = cleanString(data.name);
  const bodyParts = asList(data.body_part_id);
  const equipment = asList(data.equipment_id).join(', ');
  return {
    id: normalizeId(name, slug, usedIds),
    lyftaId: cleanString(data.id),
    slug,
    name,
    primaryMuscle: primaryMuscle(bodyParts, name, cleanString(data.image_name)),
    bodyPart: bodyParts.join(', '),
    equipment,
    exerciseType: cleanString(data.exercise_type),
    imageUrl: cleanString(data.image_name),
    videoUrl: cleanString(data.video_file),
    sourceUrl: url,
  };
}

async function mapLimit(items, workerCount, worker) {
  const result = new Array(items.length);
  let nextIndex = 0;
  async function runWorker(workerId) {
    while (nextIndex < items.length) {
      const index = nextIndex;
      nextIndex += 1;
      try {
        result[index] = await worker(items[index], index, workerId);
      } catch (error) {
        console.log(`failed ${items[index]}: ${error.message}`);
      }
    }
  }
  await Promise.all(Array.from({ length: workerCount }, (_, index) => runWorker(index)));
  return result.filter(Boolean);
}

function renderDart(exercises) {
  const generatedAt = new Date().toISOString();
  return `// GENERATED CODE - DO NOT EDIT BY HAND.
// Generated by tools/scrape_lyfta_catalog.mjs on ${generatedAt}.

class LyftaExerciseSeed {
  const LyftaExerciseSeed({
    required this.id,
    required this.lyftaId,
    required this.slug,
    required this.name,
    required this.primaryMuscle,
    required this.bodyPart,
    required this.equipment,
    required this.exerciseType,
    required this.imageUrl,
    required this.videoUrl,
    required this.sourceUrl,
  });

  final String id;
  final String lyftaId;
  final String slug;
  final String name;
  final String primaryMuscle;
  final String bodyPart;
  final String equipment;
  final String exerciseType;
  final String imageUrl;
  final String videoUrl;
  final String sourceUrl;
}

const lyftaExerciseCatalog = <LyftaExerciseSeed>[
${exercises
  .map(
    (exercise) => `  LyftaExerciseSeed(
    id: ${dartString(exercise.id)},
    lyftaId: ${dartString(exercise.lyftaId)},
    slug: ${dartString(exercise.slug)},
    name: ${dartString(exercise.name)},
    primaryMuscle: ${dartString(exercise.primaryMuscle)},
    bodyPart: ${dartString(exercise.bodyPart)},
    equipment: ${dartString(exercise.equipment)},
    exerciseType: ${dartString(exercise.exerciseType)},
    imageUrl: ${dartString(exercise.imageUrl)},
    videoUrl: ${dartString(exercise.videoUrl)},
    sourceUrl: ${dartString(exercise.sourceUrl)},
  ),`,
  )
  .join('\n')}
];
`;
}

const urls = await discoverUrls();
if (urls.length === 0) {
  throw new Error('No exercise URLs discovered');
}
const selectedUrls = limit > 0 ? urls.slice(0, limit) : urls;
const buildId = await discoverBuildId(selectedUrls[0]);
console.log(`build id ${buildId}; scraping ${selectedUrls.length}/${urls.length} exercises`);

const usedIds = new Set();
const exercises = await mapLimit(selectedUrls, concurrency, async (url, index) => {
  const exercise = await scrapeExercise(url, buildId, usedIds);
  if ((index + 1) % 100 === 0 || index === selectedUrls.length - 1) {
    console.log(`scraped ${index + 1}/${selectedUrls.length}`);
  }
  return exercise;
});

exercises.sort((a, b) => {
  const muscle = a.primaryMuscle.localeCompare(b.primaryMuscle);
  if (muscle !== 0) return muscle;
  return a.name.localeCompare(b.name);
});

await writeFile(path.join(cacheDir, 'lyfta_exercises.json'), JSON.stringify(exercises, null, 2), 'utf8');
await writeFile(outPath, renderDart(exercises), 'utf8');
console.log(`wrote ${exercises.length} exercises -> ${outPath}`);
