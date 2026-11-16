export interface RephiConfig {
  apiUrl: string;
  wsUrl: string;
  debug: boolean;
}

type Listener = (config: Readonly<RephiConfig>) => void;

const config: RephiConfig = {
  apiUrl: "/api",
  wsUrl: "/socket",
  debug: false,
};

const listeners = new Set<Listener>();

export function getRephiConfig(): Readonly<RephiConfig> {
  return config;
}

/** Undefined keys keep their value. The socket picks up a new `wsUrl` on its next `connect()`. */
export function configureRephi(overrides: Partial<RephiConfig>): Readonly<RephiConfig> {
  if (overrides.apiUrl !== undefined) config.apiUrl = overrides.apiUrl;
  if (overrides.wsUrl !== undefined) config.wsUrl = overrides.wsUrl;
  if (overrides.debug !== undefined) config.debug = overrides.debug;
  listeners.forEach((listener) => listener(config));
  return config;
}

export function onRephiConfigChange(listener: Listener): () => void {
  listeners.add(listener);
  return () => {
    listeners.delete(listener);
  };
}

export function debugLog(...args: unknown[]): void {
  if (config.debug) console.debug("[rephi]", ...args);
}
