import { env } from './env';

/**
 * Runtime configuration of the library.
 *
 * `env.SERVER_API_URL` / `env.WS_URL` are inlined when this package is built, so
 * they cannot differ between deployments of the same build. Consumers that need
 * their own endpoints (a static site on a CDN, a second environment, tests...)
 * call `configureRephi()` once, before the first request or socket connection.
 */
export interface RephiConfig {
  /** Base URL of the REST API, e.g. `https://api.example.com/api` or `/api`. */
  apiUrl: string;
  /** Phoenix socket endpoint, e.g. `wss://api.example.com/socket` or `/socket`. */
  wsUrl: string;
}

type Listener = (config: Readonly<RephiConfig>) => void;

// Defaults are the values baked in at library build time, which keeps existing
// consumers working without calling `configureRephi()`.
const config: RephiConfig = {
  apiUrl: env.SERVER_API_URL,
  wsUrl: env.WS_URL,
};

const listeners = new Set<Listener>();

/** Returns the configuration currently in effect. */
export function getRephiConfig(): Readonly<RephiConfig> {
  return config;
}

/**
 * Overrides the API and/or socket URL at runtime. Keys that are missing or
 * `undefined` keep their current value. Safe to call more than once.
 *
 * The `api` axios instance picks the new base URL up immediately; the socket
 * uses the new URL the next time `PhoenixSocket.connect()` runs.
 */
export function configureRephi(overrides: Partial<RephiConfig>): Readonly<RephiConfig> {
  if (overrides.apiUrl !== undefined) config.apiUrl = overrides.apiUrl;
  if (overrides.wsUrl !== undefined) config.wsUrl = overrides.wsUrl;
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
