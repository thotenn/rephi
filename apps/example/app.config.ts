/**
 * Settings of this app that depend on where it runs. The only place they are
 * written: vite.config.ts reads them (`base`, dev server port) and the router
 * follows `base` through `import.meta.env.BASE_URL`.
 * `mix rephi.gen.frontend` rewrites both values when it copies this app.
 */
export const appConfig = {
  /** Path Phoenix serves the build from: `/app/<folder name in apps/>`. */
  basename: "/app/example",
  /**
   * Port of the Vite dev server. It must be on the backend's CORS list (in
   * development: 3000, 5173, 5001, 5010, 4321, 8788). VITE_PORT overrides it.
   */
  port: 5001,
} as const;
