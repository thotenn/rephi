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
   * Port of the Astro dev server. It must be on the backend's CORS list (in
   * development: 3000, 5173, 5001, 5010, 4321, 8788).
   */
  port: 4321,
} as const;
