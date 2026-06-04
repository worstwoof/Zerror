const fs = require('fs');
const path = require('path');

const repoRoot = path.resolve(__dirname, '..', '..');
const manifestPath = path.join(__dirname, 'figma-sync-manifest.json');
const errors = [];

function rel(p) {
  return path.relative(repoRoot, p).replace(/\\/g, '/');
}

function requireFile(filePath, label) {
  const absolute = path.resolve(repoRoot, filePath);
  if (!fs.existsSync(absolute)) {
    errors.push(`${label} missing: ${filePath}`);
    return null;
  }
  const stat = fs.statSync(absolute);
  if (stat.size <= 0) {
    errors.push(`${label} is empty: ${filePath}`);
  }
  return absolute;
}

function readText(filePath) {
  return fs.readFileSync(filePath, 'utf8');
}

function checkFigmaScript(filePath) {
  const code = readText(filePath);
  try {
    new Function(`return (async () => {\n${code}\n})`);
  } catch (error) {
    errors.push(`Figma script syntax error: ${error.message}`);
  }
  for (const required of [
    'await figma.loadFontAsync',
    'await figma.setCurrentPageAsync',
    'return {',
    'createdNodeIds',
  ]) {
    if (!code.includes(required)) {
      errors.push(`Figma script missing required pattern: ${required}`);
    }
  }
}

const manifest = JSON.parse(readText(manifestPath));
const tokenArtifact = (manifest.localArtifacts ?? []).find(
  (item) => item.type === 'design-tokens',
);

if (manifest.figma?.fileKey !== 'FBfQTUkBHS7TnI0dOvIiIV') {
  errors.push('Unexpected Figma file key in manifest.');
}

for (const item of manifest.localArtifacts ?? []) {
  const absolute = requireFile(item.path, item.type || 'artifact');
  if (absolute && item.path.endsWith('.js')) {
    checkFigmaScript(absolute);
  }
}

let tokens = null;
if (!tokenArtifact) {
  errors.push('Manifest missing design-tokens artifact.');
} else {
  const tokenPath = requireFile(tokenArtifact.path, 'design tokens');
  if (tokenPath) {
    tokens = JSON.parse(readText(tokenPath));
  }
}

if (tokens) {
  for (const [name, value] of Object.entries(manifest.style?.colors ?? {})) {
    if (tokens.colors?.[name]?.value !== value) {
      errors.push(`token color mismatch for ${name}: manifest=${value}, tokens=${tokens.colors?.[name]?.value}`);
    }
  }
  for (const key of ['panel', 'card', 'button', 'input']) {
    if (tokens.radii?.[key] !== manifest.style?.radius?.[key]) {
      errors.push(`token radius mismatch for ${key}`);
    }
  }
}

const pubspecPath = requireFile('frontend/pubspec.yaml', 'pubspec');
const pubspec = pubspecPath ? readText(pubspecPath) : '';

for (const asset of manifest.assets ?? []) {
  requireFile(asset.path, 'asset');
  const pubspecAssetPath = asset.path.replace(/^frontend\//, '');
  if (!pubspec.includes(pubspecAssetPath)) {
    errors.push(`asset is not registered in pubspec.yaml: ${pubspecAssetPath}`);
  }
}

for (const screen of manifest.representativeScreens ?? []) {
  const sources = String(screen.source || '')
    .split(',')
    .map((source) => source.trim())
    .filter(Boolean);
  for (const source of sources) {
    requireFile(source, `screen source ${screen.name}`);
  }
}

const readmePath = requireFile('frontend/design_exports/README.md', 'README');
if (readmePath) {
  const readme = readText(readmePath);
  for (const phrase of [
    'Do not run `flutter`',
    'design-tokens.json',
    'figma-build-flat-redesign.js',
    'zerror-flat-ui-board.png',
  ]) {
    if (!readme.includes(phrase)) {
      errors.push(`README missing phrase: ${phrase}`);
    }
  }
}

if (errors.length) {
  console.error('Figma handoff verification failed:');
  for (const error of errors) {
    console.error(`- ${error}`);
  }
  process.exit(1);
}

console.log('Figma handoff verification passed.');
console.log(`Manifest: ${rel(manifestPath)}`);
console.log(`Assets: ${(manifest.assets ?? []).length}`);
console.log(`Representative screens: ${(manifest.representativeScreens ?? []).length}`);
console.log(`Token colors: ${Object.keys(tokens?.colors ?? {}).length}`);
