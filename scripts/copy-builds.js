#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

// Replaces `target` with a copy of `source`. The destination is removed first,
// so hashed assets of earlier builds do not pile up in priv/static/apps.
function replaceDirectory(source, target) {
  fs.rmSync(target, { recursive: true, force: true });
  fs.cpSync(source, target, { recursive: true });
}

// Reads the optional "rephi" field of an app's package.json:
//
//   "rephi": { "copyToPhoenix": false }
//
// `copyToPhoenix: false` keeps the app out of priv/static/apps. Use it for apps
// that are deployed elsewhere (a CDN, Cloudflare Pages...) or whose build is not
// a single-page app, which is what the Phoenix FrontendAppPlug serves.
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
    return !item.startsWith('.') && fs.lstatSync(itemPath).isDirectory();
  });

  const requestedApps = parseRequestedApps(process.argv.slice(2));
  const unknownApps = requestedApps.filter((app) => !allApps.includes(app));

  if (unknownApps.length > 0) {
    throw new Error(`Unknown app(s): ${unknownApps.join(', ')}`);
  }

  const apps = requestedApps.length > 0 ? requestedApps : allApps;

  console.log('🚀 Copying frontend builds to priv/static/apps...');

  const missing = [];

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
      replaceDirectory(distPath, targetPath);
      console.log(`✅ ${app} copied to priv/static/apps/${app}`);
    } else {
      console.error(`❌ No dist folder found for ${app} at ${distPath} (build it first)`);
      missing.push(app);
    }
  });

  // Directories left over from apps that no longer exist are still served.
  fs.readdirSync(targetDir)
    .filter((entry) => !allApps.includes(entry))
    .forEach((entry) => {
      console.warn(`⚠️  priv/static/apps/${entry} has no app in apps/ (remove it if it is stale)`);
    });

  if (missing.length > 0) {
    throw new Error(`No build to copy for: ${missing.join(', ')}`);
  }

  console.log('✨ Done copying builds!');
}

// Run the script
try {
  copyBuilds();
} catch (error) {
  console.error(`❌ Error copying builds: ${error.message}`);
  process.exit(1);
}