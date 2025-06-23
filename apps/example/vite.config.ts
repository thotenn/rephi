/// <reference types="vite/client" />

import react from "@vitejs/plugin-react";
import { env } from "@rephi/shared-components";
import { defineConfig } from "vite";
import tsconfigPaths from "vite-tsconfig-paths";

export default defineConfig({
  plugins: [react(), tsconfigPaths()],
  base: env.APPS.example.basename,
  server: {
    port: Number(env.APPS.example.settings.port) || 5010,
    open: true,
  },
  build: {
    outDir: 'dist',
    emptyOutDir: true,
  },
});
