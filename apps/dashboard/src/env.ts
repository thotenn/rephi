import { ROUTE_PATHS } from "./config/routes";

export const API_URL =
  import.meta.env.VITE_API_URL || "http://localhost:4000/api";
export const SOCKET_URL =
  import.meta.env.VITE_SOCKET_URL || "ws://localhost:4000/socket";

// Re-export route paths for convenience
export const urls = ROUTE_PATHS;

export const apisUrl = {
  default: API_URL,
  socket: SOCKET_URL,

  auth: {
    register: `/users/register`,
    login: `/users/login`,
    me: `/me`,
  },
  sockets: {
    notifications: "/notifications/broadcast",
  },
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
