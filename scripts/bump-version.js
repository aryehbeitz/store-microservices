#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

const service = process.argv[2];

if (!service) {
  console.error('Usage: node bump-version.js <service>');
  console.error('Services: frontend, backend, payment-service');
  process.exit(1);
}

const validServices = ['frontend', 'backend', 'payment-service'];
if (!validServices.includes(service)) {
  console.error(`Invalid service: ${service}`);
  console.error(`Valid services: ${validServices.join(', ')}`);
  process.exit(1);
}

const packageJsonPath = path.join(__dirname, '..', 'apps', service, 'package.json');

try {
  const packageJson = JSON.parse(fs.readFileSync(packageJsonPath, 'utf8'));

  // Parse current version (format: "1.0.0-2025-10-29")
  const versionMatch = packageJson.version.match(/^(\d+)\.(\d+)\.(\d+)-(\d{4}-\d{2}-\d{2})$/);

  if (!versionMatch) {
    console.error(`Invalid version format: ${packageJson.version}`);
    console.error('Expected format: X.Y.Z-YYYY-MM-DD');
    process.exit(1);
  }

  const [, major, minor, patch, date] = versionMatch;
  const today = new Date().toISOString().split('T')[0]; // YYYY-MM-DD

  let newVersion;
  if (date === today) {
    // Same day, increment patch
    const newPatch = parseInt(patch) + 1;
    newVersion = `${major}.${minor}.${newPatch}-${today}`;
  } else {
    // New day, reset to 1.0.0
    newVersion = `1.0.0-${today}`;
  }

  packageJson.version = newVersion;

  fs.writeFileSync(packageJsonPath, JSON.stringify(packageJson, null, 2) + '\n');

  console.log(`✅ ${service} version bumped to ${newVersion}`);

} catch (error) {
  console.error(`Error bumping version for ${service}:`, error.message);
  process.exit(1);
}
