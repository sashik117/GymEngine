import fs from 'node:fs';
import path from 'node:path';

const repoRoot = path.resolve(import.meta.dirname, '..');
const catalogPath = path.join(
  repoRoot,
  'apps/mobile/lib/data/catalog/lyfta_exercise_catalog.dart',
);
const reportPath = path.join(repoRoot, 'docs/exercise-catalog-audit.md');
const csvPath = path.join(repoRoot, 'docs/exercise-catalog-audit.csv');

const source = fs.readFileSync(catalogPath, 'utf8');

const seedPattern =
  /LyftaExerciseSeed\(\s*id: '([^']*)',\s*lyftaId: '([^']*)',\s*slug: '([^']*)',\s*name: '([^']*)',\s*primaryMuscle: '([^']*)',\s*bodyPart: '([^']*)',\s*equipment: '([^']*)',\s*exerciseType: '([^']*)',\s*imageUrl: '([^']*)',\s*videoUrl: '([^']*)',\s*sourceUrl: '([^']*)',\s*\)/g;

const items = [...source.matchAll(seedPattern)].map((match, index) => ({
  index: index + 1,
  id: match[1],
  lyftaId: match[2],
  slug: match[3],
  name: match[4],
  primaryMuscle: match[5],
  bodyPart: match[6],
  equipment: match[7],
  exerciseType: match[8],
  imageUrl: match[9],
  videoUrl: match[10],
  sourceUrl: match[11],
}));

function lookup(value) {
  return value
    .toLowerCase()
    .replace(/\((male|female)\)/gi, ' ')
    .replace(/\b(male|female)\b/gi, ' ')
    .replace(/\bversion\s*[-\s]*\d+\b/gi, ' ')
    .replace(/\b\d+\b/g, ' ')
    .replace(/[_/\\|°]+/g, ' ')
    .replace(/[^a-zа-яіїєґ0-9]+/giu, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function has(text, patterns) {
  return patterns.some((pattern) => text.includes(pattern));
}

function inferMuscle(name) {
  const text = lookup(name);

  if (has(text, ['calf', 'gastrocnemius', 'soleus', 'tibia', 'ікр'])) {
    return 'Calves';
  }
  if (has(text, ['neck'])) return 'Neck';
  if (has(text, ['wrist', 'forearm', 'finger', 'fingers', 'farmer'])) {
    return 'Forearms';
  }
  if (has(text, ['crunch', 'plank', 'abs', 'sit up', 'leg raise'])) {
    return 'Core';
  }
  if (
    has(text, [
      'triceps',
      'pushdown',
      'skullcrusher',
      'bench dip',
      'french press',
    ])
  ) {
    return 'Triceps';
  }
  if (has(text, ['biceps', 'brachialis', 'curl', 'hammer'])) {
    return 'Biceps';
  }
  if (has(text, ['glute', 'hip thrust', 'bridge', 'kickback'])) {
    return 'Glutes';
  }
  if (has(text, ['hamstring', 'leg curl', 'nordic'])) {
    return 'Hamstrings';
  }
  if (has(text, ['deadlift', 'good morning', 'back extension'])) {
    return 'Posterior';
  }
  if (has(text, ['squat', 'leg press', 'leg extension', 'lunge'])) {
    return 'Quads';
  }
  if (
    has(text, [
      'shoulder',
      'delt',
      'lateral raise',
      'front raise',
      'face pull',
    ])
  ) {
    return 'Shoulders';
  }
  if (has(text, ['bench press', 'chest', 'fly', 'pec', 'push up'])) {
    return 'Chest';
  }
  if (has(text, ['row', 'pulldown', 'pull up', 'chin up', 'shrug', 'back'])) {
    return 'Back';
  }
  return 'Custom';
}

function mediaTarget(url) {
  const decoded = decodeURIComponent(url || '').toLowerCase();
  const normalized = decoded
    .replace(/[-\s]+/g, '_')
    .replace(/__+/g, '_');
  const matches = [
    ...normalized.matchAll(
      /(^|_)(calves?|claves|feet|chest|back|waist|hips?|shoulders?|upper_arms?|forearms?|thighs?|neck|articulations)(_|\.|$)/g,
    ),
  ];
  if (matches.length === 0) return '';
  const raw = matches.at(-1)[2];
  if (raw === 'calf' || raw === 'calves' || raw === 'claves' || raw === 'feet') {
    return 'Calves';
  }
  if (raw === 'waist') return 'Core';
  if (raw === 'hip' || raw === 'hips') return 'Glutes';
  if (raw === 'upper_arm' || raw === 'upper_arms') return 'UpperArms';
  if (raw === 'thigh' || raw === 'thighs') return 'Thighs';
  if (raw === 'shoulder' || raw === 'shoulders') return 'Shoulders';
  if (raw === 'forearm' || raw === 'forearms') return 'Forearms';
  if (raw === 'articulations') return 'Mobility';
  return raw[0].toUpperCase() + raw.slice(1);
}

function allowedMediaTargets(muscle) {
  return new Set(
    {
      Chest: ['Chest'],
      Back: ['Back'],
      Quads: ['Thighs'],
      Posterior: ['Back', 'Glutes', 'Thighs', 'Core'],
      Shoulders: ['Shoulders'],
      Glutes: ['Glutes', 'Thighs', 'Back'],
      Hamstrings: ['Thighs', 'Glutes', 'Back'],
      Biceps: ['UpperArms'],
      Triceps: ['UpperArms'],
      Core: ['Core'],
      Calves: ['Calves', 'Mobility'],
      Forearms: ['Forearms'],
      Neck: ['Neck'],
      Custom: [''],
    }[muscle] ?? [''],
  );
}

function quality(item) {
  let score = 0;
  if (item.imageUrl.trim()) score += 20;
  if (item.videoUrl.trim()) score += 30;
  if (item.sourceUrl.trim()) score += 8;
  if (!/\((male|female)\)/i.test(item.name)) score += 8;
  if (!/\bversion\b/i.test(item.name)) score += 5;
  if (item.equipment.trim()) score += 3;
  return score;
}

function dedupeKey(item) {
  return `${lookup(item.name)}|${item.primaryMuscle}`;
}

const byKey = new Map();
const duplicateGroups = new Map();
for (const item of items) {
  const key = dedupeKey(item);
  duplicateGroups.set(key, (duplicateGroups.get(key) ?? 0) + 1);
  const current = byKey.get(key);
  if (!current || quality(item) > quality(current)) {
    byKey.set(key, item);
  }
}

const audited = items.map((item) => {
  const inferred = inferMuscle(item.name);
  const imageTarget = mediaTarget(item.imageUrl);
  const videoTarget = mediaTarget(item.videoUrl);
  const allowed = allowedMediaTargets(inferred);
  const flags = [];

  if (!item.imageUrl.trim()) flags.push('missing_image');
  if (!item.videoUrl.trim()) flags.push('missing_video');
  if (inferred !== 'Custom' && item.primaryMuscle !== inferred) {
    flags.push(`muscle_mismatch:${item.primaryMuscle}->${inferred}`);
  }
  if (imageTarget && !allowed.has(imageTarget)) {
    flags.push(`image_target:${imageTarget}`);
  }
  if (videoTarget && !allowed.has(videoTarget)) {
    flags.push(`video_target:${videoTarget}`);
  }
  if ((duplicateGroups.get(dedupeKey(item)) ?? 0) > 1) {
    flags.push('duplicate_group');
  }
  if (/good morning/i.test(item.name)) flags.push('reviewed_good_morning');
  if (/finger|fingers/i.test(item.name)) flags.push('reviewed_forearm_rule');

  return {
    ...item,
    inferredMuscle: inferred,
    imageTarget,
    videoTarget,
    duplicateCount: duplicateGroups.get(dedupeKey(item)) ?? 1,
    quality: quality(item),
    flags,
  };
});

const suspicious = audited.filter((item) =>
  item.flags.some(
    (flag) =>
      flag.startsWith('muscle_mismatch') ||
      flag.startsWith('image_target') ||
      flag.startsWith('video_target') ||
      flag === 'reviewed_good_morning' ||
      flag === 'reviewed_forearm_rule',
  ),
);

const stats = {
  rawExercises: items.length,
  uniqueAfterDedupe: byKey.size,
  removedDuplicateRows: items.length - byKey.size,
  duplicateGroups: [...duplicateGroups.values()].filter((count) => count > 1)
    .length,
  uniqueRowsWithImage: [...byKey.values()].filter((item) =>
    item.imageUrl.trim(),
  ).length,
  uniqueRowsWithImageAndVideo: [...byKey.values()].filter(
    (item) => item.imageUrl.trim() && item.videoUrl.trim(),
  ).length,
  missingImages: audited.filter((item) => item.flags.includes('missing_image'))
    .length,
  missingVideos: audited.filter((item) => item.flags.includes('missing_video'))
    .length,
  suspiciousRows: suspicious.length,
  goodMorningRows: audited.filter((item) =>
    item.flags.includes('reviewed_good_morning'),
  ).length,
  fingerRows: audited.filter((item) =>
    item.flags.includes('reviewed_forearm_rule'),
  ).length,
};

function escapeCsv(value) {
  return `"${String(value ?? '').replaceAll('"', '""')}"`;
}

const csvRows = [
  [
    'index',
    'id',
    'name',
    'primaryMuscle',
    'inferredMuscle',
    'bodyPart',
    'equipment',
    'imageTarget',
    'videoTarget',
    'duplicateCount',
    'quality',
    'flags',
  ],
  ...audited.map((item) => [
    item.index,
    item.id,
    item.name,
    item.primaryMuscle,
    item.inferredMuscle,
    item.bodyPart,
    item.equipment,
    item.imageTarget,
    item.videoTarget,
    item.duplicateCount,
    item.quality,
    item.flags.join(';'),
  ]),
];

fs.writeFileSync(
  csvPath,
  csvRows.map((row) => row.map(escapeCsv).join(',')).join('\n') + '\n',
);

const topSuspicious = suspicious
  .filter((item) => !item.flags.every((flag) => flag === 'duplicate_group'))
  .slice(0, 80);

const report = `# Exercise Catalog Audit

Generated by \`node tools/audit_lyfta_catalog.mjs\`.

## Summary

| Metric | Value |
| --- | ---: |
| Raw catalog rows | ${stats.rawExercises} |
| Unique rows after app dedupe | ${stats.uniqueAfterDedupe} |
| Duplicate rows hidden in UI | ${stats.removedDuplicateRows} |
| Duplicate groups | ${stats.duplicateGroups} |
| Unique rows searchable with image | ${stats.uniqueRowsWithImage} |
| Unique rows searchable with image + video | ${stats.uniqueRowsWithImageAndVideo} |
| Rows without image | ${stats.missingImages} |
| Rows without video | ${stats.missingVideos} |
| Rows with review flags | ${stats.suspiciousRows} |
| Good Morning rows reviewed | ${stats.goodMorningRows} |
| Finger / forearm rows reviewed | ${stats.fingerRows} |

## Rules Applied

- Dedupe key: normalized exercise name + primary muscle.
- UI keeps the highest-quality row in every duplicate group.
- Quality favors image, video, source URL, non-gendered names, non-versioned names, and filled equipment.
- Search UI hides rows without an exercise image and sorts video rows first.
- Good Morning variants are treated as posterior-chain work and translated as Ukrainian "нахили", not literal "good morning".
- Finger, wrist, and forearm movements are treated as forearm work, even if the raw source category is noisy.
- Calves media accepts Lyfta spelling variants such as \`Calves\`, \`Calf\`, \`Claves\`, and foot/ankle mobility targets.

## Review Sample

The full row-by-row audit is in [exercise-catalog-audit.csv](exercise-catalog-audit.csv).

| # | Name | Raw Muscle | Inferred | Flags |
| ---: | --- | --- | --- | --- |
${topSuspicious
  .map(
    (item) =>
      `| ${item.index} | ${item.name.replaceAll('|', '/')} | ${item.primaryMuscle} | ${item.inferredMuscle} | ${item.flags.join(', ')} |`,
  )
  .join('\n')}
`;

fs.writeFileSync(reportPath, report);

console.log(JSON.stringify(stats, null, 2));
