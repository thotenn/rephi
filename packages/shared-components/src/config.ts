/**
 * Runtime configuration of the library.
 *
 * Nothing is inlined when the library is built: every app passes its own
 * values once, before the first request or socket connection, usually from
 * its own build-time environment (`import.meta.env.VITE_*`, `astro:env`...).
 *
 * ```ts
 * configureRephi({
 *   apiUrl: "https://api.example.com/api",
 *   wsUrl: "wss://api.example.com/socket",
 *   debug: import.meta.env.DEV,
 * });
 * ```
 */
export interface RephiConfig {
  /** Base URL of the REST API, e.g. `https://api.example.com/api` or `/api`. */
  apiUrl: string;
  /** Phoenix socket endpoint, e.g. `wss://api.example.com/socket` or `/socket`. */
  wsUrl: string;
  /** Logs socket traffic and library diagnostics to the console. */
  debug: boolean;
}

type Listener = (config: Readonly<RephiConfig>) => void;

// Same-origin defaults: right for an app that Phoenix serves itself
// (`/app/<name>/`), where the API lives at `/api` and the socket at `/socket`.
const config: RephiConfig = {
  apiUrl: "/api",
  wsUrl: "/socket",
  debug: false,
};

const listeners = new Set<Listener>();

/** Returns the configuration currently in effect. */
export function getRephiConfig(): Readonly<RephiConfig> {
  return config;
}

/**
 * Overrides part of the configuration. Keys that are missing or `undefined`
 * keep their current value. Safe to call more than once.
 *
 * The `api` axios instance picks a new base URL up immediately; the socket
 * uses a new URL the next time `PhoenixSocket.connect()` runs.
 */
export function configureRephi(overrides: Partial<RephiConfig>): Readonly<RephiConfig> {
  if (overrides.apiUrl !== undefined) config.apiUrl = overrides.apiUrl;
  if (overrides.wsUrl !== undefined) config.wsUrl = overrides.wsUrl;
  if (overrides.debug !== undefined) config.debug = overrides.debug;
  listeners.forEach((listener) => listener(config));
  return config;
}

/** Internal: lets modules holding a derived value (the axios instance) follow changes. */
export function onRephiConfigChange(listener: Listener): () => void {
  listeners.add(listener);
  return () => {
    listeners.delete(listener);
  };
}

/** Internal: `console.debug` that only speaks when `debug` is on. */
export function debugLog(...args: unknown[]): void {
  if (config.debug) console.debug("[rephi]", ...args);
}
