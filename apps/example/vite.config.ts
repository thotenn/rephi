import react from "@vitejs/plugin-react";
import { defineConfig, loadEnv } from "vite";
import { appConfig } from "./app.config";

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, import.meta.dirname, "VITE_");

  return {
    plugins: [react()],
    resolve: {
      // Resolves the `~/*` alias from tsconfig.json `paths`.
      tsconfigPaths: true,
    },
    // Phoenix serves every `priv/static/apps/<name>` at `/app/<name>/`, and
    // `yarn build` copies `apps/<name>/dist` there.
    base: `${appConfig.basename}/`,
    server: {
      port: Number(env.VITE_PORT) || appConfig.port,
      // Another port would not be on the backend's CORS list: fail instead.
      strictPort: true,
    },
    build: {
      outDir: "dist",
      emptyOutDir: true,
    },
  };
});
