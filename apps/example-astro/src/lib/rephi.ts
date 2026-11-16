// Every island imports the library from here, never directly, so the configuration always runs first.
// eslint-disable-next-line @typescript-eslint/no-restricted-imports
import { configureRephi } from "@rephi/shared-components";
import { PUBLIC_API_URL, PUBLIC_WS_URL } from "astro:env/client";

configureRephi({ apiUrl: PUBLIC_API_URL, wsUrl: PUBLIC_WS_URL, debug: import.meta.env.DEV });

// eslint-disable-next-line @typescript-eslint/no-restricted-imports
export * from "@rephi/shared-components";
