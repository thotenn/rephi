import react from "@astrojs/react";
import tailwindcss from "@tailwindcss/vite";
import { defineConfig, envField } from "astro/config";
import { loadEnv } from "vite";
import { appConfig } from "./app.config.ts";

// astro.config is evaluated before Astro loads `.env`, so read it with Vite's loader.
const buildEnv = loadEnv(process.env.NODE_ENV ?? "production", process.cwd(), "ASTRO_");

export default defineConfig({
  output: "static",

  base: buildEnv.ASTRO_BASE || appConfig.basename,

  // Static hosts serve `<route>/index.html` at the slash URL: avoids a redirect per link.
  trailingSlash: "always",
  build: { format: "directory" },

  server: { port: appConfig.port },

  integrations: [react()],

  env: {
    schema: {
      PUBLIC_API_URL: envField.string({
        context: "client",
        access: "public",
        default: "http://localhost:4000/api",
      }),
      PUBLIC_WS_URL: envField.string({
        context: "client",
        access: "public",
        default: "ws://localhost:4000/socket",
      }),
    },
  },

  vite: {
    plugins: [tailwindcss()],
    // Missed by Vite's dependency scan: optimized late, with a full page reload.
    optimizeDeps: {
      include: [
        "astro/virtual-modules/transitions-events.js",
        "astro/virtual-modules/transitions-router.js",
        "astro/virtual-modules/transitions-swap-functions.js",
        "astro/virtual-modules/transitions-types.js",
      ],
    },
  },
});
