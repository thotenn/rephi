import { env } from "@rephi/shared-components";
import { ROUTE_PATHS } from "./config/routes";

export const API_URL = env.SERVER_API_URL;
export const SOCKET_URL = env.WS_URL;

// Re-export route paths for convenience
export const urls = ROUTE_PATHS;

export const apisUrl = {
  ...env.API,
};

export const channelsProps = {
  topics: {
    user: {
      lobby: "user:lobby",
    },
  },
  events: {
    user: {
      notification: "new_notification",
    },
  },
};

export const storeNames = {
  authToken: "auth_token",
};
