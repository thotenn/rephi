// `mix rephi.gen.frontend` rewrites these values when it copies this app.
export const appConfig = {
  basename: "/app/example",
  // Its origin must be on the backend's CORS list; VITE_PORT overrides it.
  port: 5001,
} as const;
