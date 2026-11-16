/**
 * Single entry point to `@rephi/shared-components` for this app.
 *
 * The shared library carries no build-time configuration: this module hands it
 * the app's own public environment variables before anything can issue a
 * request or open a socket.
 * Import the library from here (`~/lib/rephi`), never directly: every island is
 * a separate entry point, and this guarantees each of them runs the
 * configuration first. ESLint enforces it (see eslint.config.js).
 */
// eslint-disable-next-line @typescript-eslint/no-restricted-imports
import { configureRephi } from "@rephi/shared-components";
import { PUBLIC_API_URL, PUBLIC_WS_URL } from "astro:env/client";

configureRephi({ apiUrl: PUBLIC_API_URL, wsUrl: PUBLIC_WS_URL, debug: import.meta.env.DEV });

// eslint-disable-next-line @typescript-eslint/no-restricted-imports
export * from "@rephi/shared-components";
