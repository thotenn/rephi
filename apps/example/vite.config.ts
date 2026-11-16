import react from "@vitejs/plugin-react";
import { env } from "@rephi/shared-components";
import { defineConfig } from "vite";

export default defineConfig({
  plugins: [react()],
  resolve: {
    // Resolves the `~/*` alias from tsconfig.json `paths`.
    tsconfigPaths: true,
  },
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
