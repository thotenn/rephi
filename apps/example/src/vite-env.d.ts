/// <reference types="vite/client" />

interface ImportMetaEnv {
  /** Phoenix REST API base URL (see .env.example). */
  readonly VITE_API_URL?: string;
  /** Phoenix socket endpoint (see .env.example). */
  readonly VITE_WS_URL?: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
