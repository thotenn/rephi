import react from "@astrojs/react";
import tailwindcss from "@tailwindcss/vite";
import { defineConfig, envField } from "astro/config";
import { loadEnv } from "vite";

// `astro.config.*` is evaluated before Astro loads `.env`, so the build-time
// options below are read with Vite's loader (process env wins over `.env` files).
const buildEnv = loadEnv(process.env.NODE_ENV ?? "production", process.cwd(), "ASTRO_");

export default defineConfig({
  // Every page is prerendered to plain HTML: `dist/` is a static site that any
  // static host (Cloudflare Pages, Workers static assets, a CDN...) serves as-is.
  output: "static",

  // Sub-path the site is served from. "/" on Cloudflare Pages; set
  // ASTRO_BASE=/some/path to host it under a prefix (see the README).
  base: buildEnv.ASTRO_BASE || "/",

  // Pages are emitted as `<route>/index.html`, whose canonical URL ends with a
  // slash on static hosts. Requiring it everywhere keeps dev and production
  // consistent and avoids a redirect on every internal navigation.
  trailingSlash: "always",
  build: { format: "directory" },

  server: { port: 4321 },

  integrations: [react()],

  // Public, typed configuration. The values are inlined into the client bundle
  // when the site is built and handed to `configureRephi()` in src/lib/rephi.ts.
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
  },
});
