# Rephi example — Astro

The same application as [`apps/example`](../example) (the Vite + React single-page app), built
with [Astro](https://astro.build) as a **static, multi-page site** that can be hosted on
[Cloudflare Pages](https://pages.cloudflare.com) or any other static host, while the Phoenix
backend runs somewhere else.

It keeps every Phoenix integration of the SPA: JWT login and registration, the persisted auth
store, the axios API client, role-based guards, the admin screens (users, roles, permissions) and
live notifications over a Phoenix channel. All of them come from
[`@rephi/shared-components`](../../packages/shared-components), exactly as in the SPA.

## How it differs from the SPA

| | `apps/example` (SPA) | `apps/example-astro` |
|---|---|---|
| Output | One `index.html` + a JS bundle | One prerendered HTML file per route + small per-island bundles |
| Routing | React Router, in the browser | File-based (`src/pages`), real URLs, real `404.html` |
| Rendering | Everything rendered by React at runtime | Static shell rendered at build time, React only inside islands |
| Navigation | Client-side router | Astro client router (`<ClientRouter />`) between prerendered pages |
| Hosting | Served by Phoenix under `/app/example` | Any static host; Phoenix only provides the API and the socket |
| API / socket URL | Inlined into the shared library when it is built | `PUBLIC_API_URL` / `PUBLIC_WS_URL` of this app, applied at runtime |
| Requests | Same origin as the API | Cross-origin: the backend must allow the site's origin |

## Architecture

```
src/
├── pages/            One .astro file per route (/, /login, /register, /home, /pages/*, /admin/*, 404)
├── layouts/
│   ├── BaseLayout.astro   <html>, <head>, client router, the persisted runtime island
│   └── AppLayout.astro    Signed-in shell: route guard + header + <main>
├── components/       Static Astro components (header, card) and shared React pieces (react/)
├── islands/          React components hydrated in the browser
├── hooks/            useLogin / useRegister / logout
├── lib/              rephi.ts (runtime configuration), routes, navigation, realtime state, API calls
└── styles/           Tailwind CSS entry point
```

### Pages and islands

Astro renders each page to HTML at build time. Only the parts that need the browser are React
islands, and each one states how it is loaded:

| Island | Directive | Why |
|---|---|---|
| `AppRuntime` (socket, notifications, toasts) | `client:only` + `transition:persist` | Needs the stored session and a WebSocket, so there is nothing to prerender. Persisted so the client router keeps it (and its socket) alive across pages. |
| `RouteGuard` (wraps every signed-in page) | `client:only` | Access depends on the session stored in the browser. The page is shipped as inert HTML inside the island and inserted once the guard allows it; a static "Loading..." fallback is shown until then. |
| `GuestRedirect` (welcome, login, register) | `client:only` | No markup; it only redirects visitors who are already signed in. |
| `LoginForm`, `RegisterForm` | `client:load` | Prerendered so the form is visible before any JavaScript runs, hydrated immediately. Their markup does not depend on the session. |
| `LogoutButton` | `client:load` | Same markup for everyone: prerendered (no layout shift), hydrated at once. |
| `AdminMenu` | `client:only` | Rendered for admins only, which is known in the browser only. |
| `UserInfoCard` | `client:only` | Shows the signed-in user. |
| `NotificationSender` | `client:only` | Shows the live state of the socket. |
| `UsersManagement`, `RolesManagement`, `PermissionsManagement` | `client:only` | Everything they display comes from authenticated API calls. |

`client:only` is used wherever the output depends on the session: the store is persisted in
`localStorage`, so at build time the only possible render is the signed-out one, which would be
shipped for nothing and then replaced in the browser.

The dashboard page, the header, the active navigation link, page titles and the 404 page are
plain Astro and ship no JavaScript of their own.

### Navigation

Pages are separate HTML documents, linked with normal `<a href>` elements.
`<ClientRouter />` (Astro's view-transition router) intercepts those links, fetches the next page
and swaps the document in place. This matters for the socket: a full page load closes the
WebSocket and opens a new one, while a client-side navigation keeps the persisted `AppRuntime`
island, so the connection stays open and visible toasts are not lost.

Nothing depends on the router being active: if a navigation falls back to a full page load
(old browser, a reload, a deep link), the page boots on its own and the socket reconnects.

### Authentication and guards

The session (user + JWT) lives in the browser, in the persisted store of the shared library.
Route protection is therefore client-side, as in the SPA, and it is a user-experience feature:
the API authorizes every request on its own.

- **Signed-in pages** use `AppLayout`, which wraps the page in `RouteGuard`. A signed-out visitor
  is sent to `/login/` and the requested URL is remembered, so the login returns there.
- **Admin pages** pass `access="admin"`; other users get the access-denied screen.
- **Public-only pages** (`/`, `/login/`, `/register/`) pass `guestOnly` to `BaseLayout`:
  a signed-in visitor is sent to `/home/`. Because these pages are painted before any island
  loads, a small inline script in `<head>` does the same check before the first paint, so the
  public page does not flash.
- **Logout** only clears the store. `RouteGuard` reacts by navigating to the login page and
  `AppRuntime` closes the socket.

### Realtime

`AppRuntime` is the only place that opens the socket and joins `user:lobby`, so a notification is
shown exactly once whatever the page. Islands that need the connection state (the badge on the
home page) read it from `src/lib/realtime.ts`.

### Configuration flow

```
.env / host environment      PUBLIC_API_URL, PUBLIC_WS_URL
        │  validated and typed by the `env.schema` of astro.config.ts
        ▼
astro:env/client             imported by src/lib/rephi.ts
        │  configureRephi({ apiUrl, wsUrl })
        ▼
@rephi/shared-components     axios instance + Phoenix socket use the configured URLs
```

Every island imports the shared library through `~/lib/rephi`, never directly, so the
configuration is applied before the first request (ESLint enforces it).

## Requirements

- Node.js 22.23.4 or newer (the repository pins the version in `.tool-versions`)
- Yarn 4 through Corepack
- A running Rephi backend (`mix phx.server` in the repository root)

## Development

From the repository root:

```bash
yarn install
yarn shared:build          # the app imports the compiled shared library
yarn example-astro:dev     # http://localhost:4321
```

The dev server listens on port **4321**. To use another port:

```bash
yarn example-astro:dev --port 5173
```

The backend answers browsers only from the origins on its CORS allow-list (see
[Backend requirements](#backend-requirements)), so the origin of the dev server, port included,
has to be on that list.

Other scripts (run them with `yarn workspace rephi-example-astro <script>`):

| Script | What it does |
|---|---|
| `dev` | Astro dev server with hot reloading |
| `build` | `astro check` (types of `.astro`, `.ts` and `.tsx` files), then the static build into `dist/` |
| `preview` | Serves `dist/` with Astro's preview server |
| `typecheck` | `astro check` |
| `lint` | ESLint on `.astro`, `.ts` and `.tsx` files |
| `clean` | Removes `dist/` and the generated `.astro/` folder |
| `pages:dev` | Serves `dist/` with the local Cloudflare Pages emulator |
| `pages:deploy` | Uploads `dist/` to Cloudflare Pages |

In development, Astro's client router loads the next page in a hidden iframe when it contains
`client:only` islands, to collect their styles. That is why a page may request its data twice
while navigating in dev. It does not happen in a production build.

## Environment variables

Copy `.env.example` to `.env` to override the defaults.

| Variable | Default | Purpose |
|---|---|---|
| `PUBLIC_API_URL` | `http://localhost:4000/api` | Base URL of the Phoenix REST API |
| `PUBLIC_WS_URL` | `ws://localhost:4000/socket` | Phoenix socket endpoint |
| `ASTRO_BASE` | `/` | Sub-path the site is served from (see [Base path](#base-path)) |

The `PUBLIC_*` variables are public by design: they end up in the JavaScript sent to the
browser. All three are read **when the site is built** (or when the dev server starts), so a
deployment gets its values from the environment of its build, and changing them means
rebuilding. Never put a secret in them.

## Build

```bash
yarn shared:build
yarn example-astro:build
```

The result is `apps/example-astro/dist/`: HTML files, hashed assets under `_astro/`, the files of
`public/`, and the Cloudflare `_headers` file. No server code is produced.

```bash
PUBLIC_API_URL=https://api.example.com/api \
PUBLIC_WS_URL=wss://api.example.com/socket \
yarn example-astro:build
```

## Deploying to Cloudflare Pages

The site needs nothing from Cloudflare except static hosting: no Functions, no bindings.

- `wrangler.jsonc` names the project and declares `dist` as the Pages build output directory.
- `public/_headers` sets the response headers: security headers on every response, HTML always
  revalidated, hashed assets under `/_astro/` cached for a year as immutable.
- `dist/404.html` makes Pages answer unknown URLs with a real 404 page. (Without that file Pages
  would treat the project as a single-page app and serve the home page instead.)
- No `_redirects` file is needed: Pages serves `/login/` from `login/index.html` and redirects
  `/login` to `/login/` on its own.

### Git integration

Create a Pages project connected to the repository and use these build settings:

| Setting | Value |
|---|---|
| Framework preset | None |
| Root directory | *(empty: the repository root)* |
| Build command | `yarn shared:build && yarn example-astro:build` |
| Build output directory | `apps/example-astro/dist` |

Environment variables, for both the Production and the Preview environment:

| Variable | Value |
|---|---|
| `NODE_VERSION` | `26.13.1` (the version pinned in `.tool-versions`; at least `22.23.4`) |
| `YARN_VERSION` | `4.18.1` (the version of `packageManager` in the root `package.json`) |
| `PUBLIC_API_URL` | `https://api.example.com/api` |
| `PUBLIC_WS_URL` | `wss://api.example.com/socket` |

The root directory is the repository root because this is a Yarn workspace: dependencies are
installed from the root `yarn.lock`, and the shared library has to be built before the app.

Optionally, restrict the build watch paths to `apps/example-astro/*`,
`packages/shared-components/*`, `package.json` and `yarn.lock`, so unrelated commits do not
trigger a deployment.

With these settings Pages reads its configuration from the dashboard. `wrangler.jsonc` lives in
this folder, not in the root directory of the build, and is used by the Wrangler commands below.
(`.node-version` in this folder serves the same purpose for a project whose root directory is
`apps/example-astro`.)

### Direct upload with Wrangler

Build locally (or in your own CI) with the production values, then upload `dist/`:

```bash
PUBLIC_API_URL=https://api.example.com/api \
PUBLIC_WS_URL=wss://api.example.com/socket \
yarn example-astro:build

cd apps/example-astro
yarn wrangler pages project create <your-project> --production-branch main   # first time only
yarn pages:deploy --project-name <your-project>
```

Wrangler needs to be authenticated: `yarn wrangler login`, or the `CLOUDFLARE_API_TOKEN` and
`CLOUDFLARE_ACCOUNT_ID` environment variables in CI. Without `--project-name`, the `name` of
`wrangler.jsonc` is used.

### Local preview of the Pages build

```bash
yarn example-astro:build
yarn workspace rephi-example-astro pages:dev        # http://localhost:8788
```

This serves `dist/` the way Pages does, including `_headers`, the trailing-slash redirects and
the 404 page. Pass `--port <port>` to change the port. No Cloudflare account is required.
The script binds to `127.0.0.1` explicitly, because Wrangler's default (`localhost`) fails to
start on machines where IPv6 is disabled.

### On-demand rendering later

The app is static on purpose. If a route ever needs to run on the server (an API endpoint, a
page rendered per request), add Astro's Cloudflare adapter:

```bash
yarn workspace rephi-example-astro astro add cloudflare
```

and opt the route out of prerendering with `export const prerender = false`. Be aware that the
current adapter targets **Cloudflare Workers** (static assets plus a Worker), not Pages
Functions: the deployment then moves from `wrangler pages deploy` to `wrangler deploy`, and the
Wrangler configuration changes accordingly. See Astro's
[Cloudflare guide](https://docs.astro.build/en/guides/deploy/cloudflare/).

## Backend requirements

The site and the API are on different origins, so the Phoenix backend has to accept the site:

1. **CORS**: the site's origin (scheme + host + port, no path) must be on the allow-list of
   `CORSPlug` in `lib/rephi_web/endpoint.ex`, with credentials enabled. A wildcard `*` does not
   work, because the API client sends credentialed requests.

   ```elixir
   plug CORSPlug,
     origin: [
       "http://localhost:4321",
       "https://<your-project>.pages.dev",
       "https://app.example.com"
     ],
     credentials: true
   ```

   Preview deployments get their own host name (`https://<hash>.<your-project>.pages.dev`).
   `CORSPlug` accepts regular expressions if you want to allow them.

2. **WebSocket origin check**: in production Phoenix compares the `Origin` header of a socket
   connection with the endpoint's own host and rejects anything else. List the site's origins
   in the endpoint configuration (`config/runtime.exs`):

   ```elixir
   config :rephi, RephiWeb.Endpoint,
     check_origin: [
       "https://<your-project>.pages.dev",
       "https://app.example.com"
     ]
   ```

   `"//*.<your-project>.pages.dev"` matches every preview deployment.

3. **HTTPS**: a site served over HTTPS can only call an `https://` API and a `wss://` socket.

## Base path

The site is built for the domain root. To host it under a sub-path, set `ASTRO_BASE` at build
time; internal links, assets and the "redirect back after login" target all follow it:

```bash
ASTRO_BASE=/some/path yarn example-astro:build
```

The files in `dist/` are not moved into a sub-folder by this: upload them so that
`dist/index.html` is served at `/some/path/`. The paths in `public/_headers` assume the root and
need the same prefix.

### Serving it from Phoenix

`yarn build` at the repository root copies every `apps/*/dist` into `priv/static/apps/`, where
`RephiWeb.Plugs.FrontendAppPlug` serves them as single-page apps: any unknown path gets the root
`index.html`. That is wrong for a multi-page site (`/app/x/login/` must be answered with
`login/index.html`), so this app opts out of the copy:

```json
"rephi": { "copyToPhoenix": false }
```

To serve it from Phoenix anyway, the plug first has to resolve directory indexes and serve
`404.html` for unknown paths. Then build with the Phoenix path and copy it explicitly:

```bash
ASTRO_BASE=/app/example-astro PUBLIC_API_URL=/api PUBLIC_WS_URL=/socket yarn example-astro:build
node scripts/copy-builds.js --app example-astro
```

## Linting and type checking

```bash
yarn workspace rephi-example-astro lint
yarn workspace rephi-example-astro typecheck
```

Both also run as part of `yarn lint` and `yarn typecheck` at the repository root.
