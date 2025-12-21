#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

// Read version from package.json
const packageJsonPath = path.join(__dirname, 'package.json');
const packageJson = JSON.parse(fs.readFileSync(packageJsonPath, 'utf8'));
const version = packageJson.version;

// Replace {{VERSION}} in index.html
const indexHtmlPath = path.join(__dirname, 'src', 'index.html');
let indexHtml = fs.readFileSync(indexHtmlPath, 'utf8');
indexHtml = indexHtml.replace(/\{\{VERSION\}\}/g, version);
fs.writeFileSync(indexHtmlPath, indexHtml);

// Create version.json file
const versionJsonPath = path.join(__dirname, 'src', 'assets', 'version.json');
const versionJson = {
  service: 'frontend',
  version: version,
  timestamp: new Date().toISOString()
};
// Ensure assets directory exists
const assetsDir = path.join(__dirname, 'src', 'assets');
if (!fs.existsSync(assetsDir)) {
  fs.mkdirSync(assetsDir, { recursive: true });
}
fs.writeFileSync(versionJsonPath, JSON.stringify(versionJson, null, 2));

// Update version.service.ts
const versionServicePath = path.join(__dirname, 'src', 'app', 'services', 'version.service.ts');
let versionService = fs.readFileSync(versionServicePath, 'utf8');
versionService = versionService.replace(/'\{\{VERSION\}\}'/g, `'${version}'`);
fs.writeFileSync(versionServicePath, versionService);

console.log(`✅ Version ${version} injected into build files`);

