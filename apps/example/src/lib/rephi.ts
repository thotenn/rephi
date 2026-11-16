import { configureRephi } from "@rephi/shared-components";

const devDefaults = { apiUrl: "http://localhost:4000/api", wsUrl: "ws://localhost:4000/socket" };
const buildDefaults = { apiUrl: "/api", wsUrl: "/socket" };
const defaults = import.meta.env.DEV ? devDefaults : buildDefaults;

configureRephi({
  apiUrl: import.meta.env.VITE_API_URL || defaults.apiUrl,
  wsUrl: import.meta.env.VITE_WS_URL || defaults.wsUrl,
  debug: import.meta.env.DEV,
});
