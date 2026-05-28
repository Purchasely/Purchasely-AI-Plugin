import fs from 'node:fs';
import path from 'node:path';

const root = process.cwd();
const textExtensions = new Set(['.md', '.json', '.js', '.mjs']);
const ignoredDirs = new Set(['.git', 'node_modules', '.antigravitycli']);

function* walk(dir) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    if (ignoredDirs.has(entry.name)) continue;
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      yield* walk(fullPath);
    } else if (textExtensions.has(path.extname(entry.name))) {
      yield fullPath;
    }
  }
}

function isInstructionalNegative(line) {
  return /\b(do not|don't|never|not exposed|no universal|there is no|wrong|bad|known-bad)\b/i.test(line);
}

const failures = [];

function lineNumberForIndex(content, index) {
  return content.slice(0, index).split(/\r?\n/).length;
}

const requiredBuildGateSkillFiles = [
  'purchasely/skills/purchasely-debug/SKILL.md',
  'purchasely/skills/purchasely-integrate/SKILL.md',
  'purchasely/skills/purchasely-review/SKILL.md',
];

for (const rel of requiredBuildGateSkillFiles) {
  let content;
  try {
    content = fs.readFileSync(path.join(root, rel), 'utf8');
  } catch {
    failures.push(`${rel} could not be read (file missing or unreadable)`);
    continue;
  }

  if (!content.includes('## Completion Build Gate')) {
    failures.push(`${rel} is missing the completion build gate`);
  }
  if (!/If the build fails[\s\S]{0,600}(fix|repair)[\s\S]{0,600}(rerun|re-run|run .*again)/i.test(content)) {
    failures.push(`${rel} does not require fixing failed builds and rerunning verification`);
  }
}

for (const file of walk(root)) {
  const rel = path.relative(root, file);
  if (rel === 'scripts/guard-known-bad-snippets.mjs') continue;
  const content = fs.readFileSync(file, 'utf8');
  const lines = content.split(/\r?\n/);

  const multilinePurchaseObject = /Purchasely\.purchase\(\{[\s\S]{0,300}\bplanId\b/g;
  for (const match of content.matchAll(multilinePurchaseObject)) {
    const matchIndex = match.index ?? 0;
    const context = content.slice(Math.max(0, matchIndex - 120), matchIndex + match[0].length);
    if (!isInstructionalNegative(context)) {
      failures.push(`${rel}:${lineNumberForIndex(content, matchIndex)} uses invented multiline RN/Flutter purchase object syntax`);
    }
  }

  lines.forEach((line, index) => {
    const where = `${rel}:${index + 1}`;
    const normalized = line.trim();

    if (/Purchasely\.purchase\(\{\s*planId/.test(line) && !isInstructionalNegative(line)) {
      failures.push(`${where} uses invented RN/Flutter purchase object syntax`);
    }
    if (/purchase\(planId:/.test(line) && !isInstructionalNegative(line)) {
      failures.push(`${where} uses invented iOS/Flutter purchase(planId:) syntax`);
    }
    if (rel.includes('cordova') && /Purchasely\.start\(\{/.test(line)) {
      failures.push(`${where} uses object-form Cordova start syntax`);
    }
    if ((rel.includes('flutter') || rel.includes('cordova')) && /setUserAttributeWithNumber/.test(line)) {
      failures.push(`${where} uses stale numeric attribute API`);
    }
    if ((rel.includes('react-native') || rel.includes('flutter') || rel.includes('cordova')) && /closeAllScreens\(\)/.test(line) && !/native|future|custom bridge/i.test(line)) {
      failures.push(`${where} uses native closeAllScreens() in a bridge reference`);
    }
    if (/storePromotionalOffer/.test(line)) {
      failures.push(`${where} uses stale iOS promotional-offer parameter`);
    }
    if (/allowDeeplink/.test(line)) {
      failures.push(`${where} uses SDK 6 deeplink readiness name in 5.x references`);
    }
    if (/userSubscriptions\(invalidateCache/.test(line) && rel.includes('flutter')) {
      failures.push(`${where} uses unsupported Flutter userSubscriptions invalidateCache parameter`);
    }
  });
}

if (failures.length > 0) {
  console.error('Known-bad Purchasely snippets found:\n' + failures.join('\n'));
  process.exit(1);
}

console.log('Known-bad Purchasely snippet guard passed.');
