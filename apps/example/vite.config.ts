import { basename } from "node:path";
import react from "@vitejs/plugin-react";
import { defineConfig, loadEnv } from "vite";

// Phoenix serves every `priv/static/apps/<name>` at `/app/<name>/`, and
// `yarn build` copies `apps/<name>/dist` there: the folder name of this app is
// its URL. A copy of this app under another folder needs no change here.
const APP_NAME = basename(import.meta.dirname);

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, import.meta.dirname, "VITE_");

  return {
    plugins: [react()],
    resolve: {
      // Resolves the `~/*` alias from tsconfig.json `paths`.
      tsconfigPaths: true,
    },
    base: `/app/${APP_NAME}/`,
    server: {
      port: Number(env.VITE_PORT) || 5001,
      strictPort: true,
    },
    build: {
      outDir: "dist",
      emptyOutDir: true,
    },
  };
});
