/// <reference types="vite/client" />

import react from "@vitejs/plugin-react";
import { env } from "@rephi/shared-components";
import { defineConfig } from "vite";
import tsconfigPaths from "vite-tsconfig-paths";

export default defineConfig({
  plugins: [react(), tsconfigPaths()],
  server: {
    port: Number(env.APPS_SETTINGS.APP_EXAMPLE_PORT) || 5010,
    open: true,
  },
  build: {
    outDir: 'dist',
    emptyOutDir: true,
  },
});
