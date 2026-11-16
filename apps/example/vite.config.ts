import react from "@vitejs/plugin-react";
import { defineConfig, loadEnv } from "vite";
import { appConfig } from "./app.config.ts";

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, import.meta.dirname, "VITE_");

  return {
    plugins: [react()],
    resolve: {
      tsconfigPaths: true,
    },
    base: `${appConfig.basename}/`,
    server: {
      port: Number(env.VITE_PORT) || appConfig.port,
      // Another port would not be on the backend's CORS list: fail instead.
      strictPort: true,
      watch: {
        // Playwright writes its results under e2e/: each write reloaded the page under test.
        ignored: ["**/e2e/**"],
      },
    },
    build: {
      outDir: "dist",
      emptyOutDir: true,
    },
  };
});
