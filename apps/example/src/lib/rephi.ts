/**
 * Configures `@rephi/shared-components` for this app. Imported first by
 * `main.tsx`, so it runs before anything can send a request or open a socket.
 *
 * Under `vite dev` the app runs on its own port, so the API defaults to the
 * local Phoenix server; a build is served by Phoenix itself (`/app/example/`)
 * and talks to its own origin.
 */
import { configureRephi } from "@rephi/shared-components";

const devDefaults = { apiUrl: "http://localhost:4000/api", wsUrl: "ws://localhost:4000/socket" };
const buildDefaults = { apiUrl: "/api", wsUrl: "/socket" };
const defaults = import.meta.env.DEV ? devDefaults : buildDefaults;

configureRephi({
  apiUrl: import.meta.env.VITE_API_URL || defaults.apiUrl,
  wsUrl: import.meta.env.VITE_WS_URL || defaults.wsUrl,
  debug: import.meta.env.DEV,
});
