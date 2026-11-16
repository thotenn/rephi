import { execFileSync } from 'node:child_process';
import { resolve } from 'node:path';
import { defineConfig, type Plugin } from 'vite';
import react from '@vitejs/plugin-react';

// Emitting the .d.ts from the build keeps them after `emptyOutDir` and refreshes them in watch mode.
function emitDeclarations(): Plugin {
  return {
    name: 'rephi:emit-declarations',
    apply: 'build',
    closeBundle() {
      try {
        execFileSync('tsc', ['--emitDeclarationOnly'], {
          cwd: import.meta.dirname,
          stdio: 'inherit',
          shell: process.platform === 'win32'
        });
      } catch (error) {
        // tsc already printed its diagnostics; keep the watcher alive.
        if (this.meta.watchMode) return;
        throw error;
      }
    }
  };
}

export default defineConfig({
  plugins: [react(), emitDeclarations()],
  build: {
    lib: {
      entry: resolve(import.meta.dirname, 'src/index.ts'),
      formats: ['es', 'cjs'],
      fileName: (format) => `index.${format === 'es' ? 'mjs' : 'js'}`
    },
    rolldownOptions: {
      external: [
        'react',
        'react/jsx-runtime',
        'phoenix',
        'axios',
        'zustand',
        'zustand/middleware'
      ]
    }
  }
});
