import { execFileSync } from 'node:child_process';
import { resolve } from 'node:path';
import { defineConfig, type Plugin } from 'vite';
import react from '@vitejs/plugin-react';

/**
 * Emits the `.d.ts` files with `tsc` once the bundle is written.
 *
 * Doing it from the build (instead of a separate `&& tsc` step) keeps the
 * declarations in `dist` after `emptyOutDir` and refreshes them on every
 * rebuild in watch mode (`yarn workspace @rephi/shared-components dev`).
 */
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
      // Everything listed in `dependencies` / `peerDependencies` stays external
      // so consumers resolve a single copy of each.
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
