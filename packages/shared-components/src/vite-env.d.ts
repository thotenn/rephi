/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_SERVER_API_URL: string
  readonly VITE_WS_URL: string
  readonly VITE_EXAMPLE_PORT: number
  readonly MODE: string
  readonly DEV: boolean
  readonly PROD: boolean
}

interface ImportMeta {
  readonly env: ImportMetaEnv
}

// `process.env.NODE_ENV` is not replaced by the library build: it is left for
// the consumer's bundler to define, so only this one key is typed here.
declare const process: { readonly env: { readonly NODE_ENV?: string } };

// Injected by the Phoenix plug that serves the built SPA.
interface Window {
  __CSRF_TOKEN__?: string
}
