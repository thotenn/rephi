/**
 * Settings of this app that depend on where it runs. The only place they are
 * written: astro.config.ts reads them.
 * `mix rephi.gen.frontend` rewrites both values when it copies this app.
 */
export const appConfig = {
  /**
   * Path the site is served from: "/" on Cloudflare Pages. The ASTRO_BASE
   * environment variable overrides it at build time (see the README).
   */
  basename: "/",
  /**
   * Port of the Astro dev server. Its origin must be on the backend's CORS list
   * (`:cors_origins` in config/dev.exs).
   */
  port: 4321,
} as const;
