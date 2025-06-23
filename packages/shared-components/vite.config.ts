import { defineConfig, loadEnv } from 'vite';
import react from '@vitejs/plugin-react';
import dts from 'vite-plugin-dts';
import { resolve } from 'path';

export default defineConfig(({ mode }) => {
  // Load env file from root directory
  const env = loadEnv(mode, resolve(__dirname, '../..'), '');
  
  return {
  plugins: [
    react(),
    dts({
      insertTypesEntry: true,
      include: ['src'],
      exclude: ['**/*.test.ts', '**/*.test.tsx']
    })
  ],
  build: {
    lib: {
      entry: resolve(__dirname, 'src/index.ts'),
      name: 'RephiSharedComponents',
      formats: ['es', 'cjs'],
      fileName: (format) => `index.${format === 'es' ? 'mjs' : 'js'}`
    },
    rollupOptions: {
      external: ['react', 'react-dom', 'phoenix'],
      output: {
        globals: {
          react: 'React',
          'react-dom': 'ReactDOM',
          phoenix: 'Phoenix'
        }
      }
    }
  },
  resolve: {
    alias: {
      '@': resolve(__dirname, './src')
    }
  },
  envDir: resolve(__dirname, '../..'),
  envPrefix: 'VITE_'
  };
});