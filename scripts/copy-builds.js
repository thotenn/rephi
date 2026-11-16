#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

// Helper function to copy directory recursively
function copyRecursive(source, target) {
  if (!fs.existsSync(source)) {
    console.warn(`Source directory ${source} does not exist`);
    return;
  }

  // Create target directory if it doesn't exist
  if (!fs.existsSync(target)) {
    fs.mkdirSync(target, { recursive: true });
  }

  // Read source directory
  const files = fs.readdirSync(source);

  files.forEach((file) => {
    const sourcePath = path.join(source, file);
    const targetPath = path.join(target, file);

    if (fs.lstatSync(sourcePath).isDirectory()) {
      copyRecursive(sourcePath, targetPath);
    } else {
      fs.copyFileSync(sourcePath, targetPath);
    }
  });
}

// Reads the optional "rephi" field of an app's package.json:
//
//   "rephi": { "copyToPhoenix": false }
//
// `copyToPhoenix: false` keeps the app out of priv/static/apps. Use it for apps
// that are deployed elsewhere (a CDN, Cloudflare Pages...) or whose build is not
// a single-page app, which is what RephiWeb.Plugs.FrontendAppPlug serves.
function readAppConfig(appDir) {
  const packageJsonPath = path.join(appDir, 'package.json');

  if (!fs.existsSync(packageJsonPath)) {
    return {};
  }

  try {
    return JSON.parse(fs.readFileSync(packageJsonPath, 'utf8')).rephi || {};
  } catch (error) {
    console.warn(`⚠️  Could not read ${packageJsonPath}: ${error.message}`);
    return {};
  }
}

// `--app <name>` (repeatable) copies only the named apps, including the ones
// that opted out with `copyToPhoenix: false`.
function parseRequestedApps(argv) {
  const requested = [];

  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === '--app' && argv[i + 1]) {
      requested.push(argv[++i]);
    } else if (argv[i].startsWith('--app=')) {
      requested.push(argv[i].slice('--app='.length));
    }
  }

  return requested;
}

// Main function
function copyBuilds() {
  const rootDir = path.resolve(__dirname, '..');
  const appsDir = path.join(rootDir, 'apps');
  const targetDir = path.join(rootDir, 'priv', 'static', 'apps');

  // Create target directory if it doesn't exist
  if (!fs.existsSync(targetDir)) {
    fs.mkdirSync(targetDir, { recursive: true });
  }

  // Get all apps directories
  const allApps = fs.readdirSync(appsDir).filter((item) => {
    const itemPath = path.join(appsDir, item);
    return fs.lstatSync(itemPath).isDirectory();
  });

  const requestedApps = parseRequestedApps(process.argv.slice(2));
  const unknownApps = requestedApps.filter((app) => !allApps.includes(app));

  if (unknownApps.length > 0) {
    throw new Error(`Unknown app(s): ${unknownApps.join(', ')}`);
  }

  const apps = requestedApps.length > 0 ? requestedApps : allApps;

  console.log('🚀 Copying frontend builds to priv/static/apps...');

  // Copy each app's dist folder
  apps.forEach((app) => {
    const distPath = path.join(appsDir, app, 'dist');
    const targetPath = path.join(targetDir, app);
    const config = readAppConfig(path.join(appsDir, app));

    if (requestedApps.length === 0 && config.copyToPhoenix === false) {
      console.log(`⏭️  Skipping ${app} ("rephi.copyToPhoenix" is false in its package.json)`);

      if (fs.existsSync(targetPath)) {
        console.warn(`⚠️  priv/static/apps/${app} exists from an earlier copy and was left untouched`);
      }

      return;
    }

    if (fs.existsSync(distPath)) {
      console.log(`📦 Copying ${app} build...`);
      copyRecursive(distPath, targetPath);
      console.log(`✅ ${app} copied to priv/static/apps/${app}`);
    } else {
      console.warn(`⚠️  No dist folder found for ${app} at ${distPath}`);
    }
  });

  console.log('✨ Done copying builds!');
}

// Run the script
try {
  copyBuilds();
} catch (error) {
  console.error('❌ Error copying builds:', error);
  process.exit(1);
}