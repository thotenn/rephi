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
  const apps = fs.readdirSync(appsDir).filter((item) => {
    const itemPath = path.join(appsDir, item);
    return fs.lstatSync(itemPath).isDirectory();
  });

  console.log('🚀 Copying frontend builds to priv/static/apps...');

  // Copy each app's dist folder
  apps.forEach((app) => {
    const distPath = path.join(appsDir, app, 'dist');
    const targetPath = path.join(targetDir, app);

    if (fs.existsSync(distPath)) {
      console.log(`📦 Copying ${app} build...`);
      copyRecursive(distPath, targetPath);
      console.log(`✅ ${app} copied to priv/static/apps/${app}`);
    } else {
      console.warn(`⚠️  No dist folder found for ${app} at ${distPath}`);
    }
  });

  console.log('✨ All builds copied successfully!');
}

// Run the script
try {
  copyBuilds();
} catch (error) {
  console.error('❌ Error copying builds:', error);
  process.exit(1);
}