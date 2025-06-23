// Environment variables configuration
// These are resolved at build time from the root .env file

const SERVER_API_URL = import.meta.env.VITE_SERVER_API_URL || 'http://localhost:4000/api';
const WS_URL = import.meta.env.VITE_WS_URL || 'ws://localhost:4000/socket';

export const env = {
  SERVER_API_URL: SERVER_API_URL,
  WS_URL: WS_URL,
  NODE_ENV: import.meta.env.MODE || 'development',
  IS_DEV: import.meta.env.DEV,
  IS_PROD: import.meta.env.PROD,
  APPS: {
    example: {
      basename: "/app/example",
      settings: {
        port: import.meta.env.VITE_EXAMPLE_PORT || '5001'
      }
    }
  },
  STORES: {
    exampleStore: {
      authToken: "auth_token",
    }
  },
  API: {
    default: SERVER_API_URL,
    socket: WS_URL,
    auth: {
      register: `/users/register`,
      login: `/users/login`,
      me: `/me`,
    },
    sockets: {
      notifications: "/notifications/broadcast",
    },
  }
} as const;

// Type-safe environment variables
export type Env = typeof env;
