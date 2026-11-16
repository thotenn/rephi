# Browser tests (Playwright)

End-to-end tests of `apps/example`: a real browser drives the app against a real Phoenix API.

| Spec | Covers |
|------|--------|
| `dashboard.spec.ts` | Every dashboard quick action: where it goes, what it opens, who sees it (administrator, manager, plain user). |
| `actions.spec.ts` | Sign in, register, logout, password change; assigning and removing roles and permissions; editing and deleting users, roles and permissions. |
| `realtime.spec.ts` | The dashboard counters per role (an administrator sees all three, a plain user only its own notifications and the sessions), refetched after a send; "Send a test to myself" shown once to the sender and to nobody else; broadcasts reaching everybody. |
| `presence.spec.ts` | "Active sessions" goes up when a second user signs in and back down when it leaves. It is the Playwright project `presence`, run after the others (project `app`): the count is global to the API, so it needs nothing else connected. |
| `controls.spec.ts` | "No dead controls": on every page, each visible link and button is clicked on a fresh page and must navigate, send a request, open a confirmation or change the page. Logout, Assign and Remove are skipped there (`actions.spec.ts` runs them on throwaway data); a Delete confirmation is dismissed. |

The tests create the accounts, roles and permissions they need through the API and delete them
afterwards. Still, run them against a database of their own, never against one you care about.

## Running

The suite needs the API with rate limiting off (it signs in and registers more often than the
limiter allows) and a dev server of this app pointed at it. The defaults are an API on `:4100` and
the app on `:5101`, so they do not collide with a development stack on `:4000` / `:5001`.

Let Playwright start both (from the repository root):

```bash
yarn shared:build
E2E_START_STACK=1 yarn example:e2e
```

This runs `mix ecto.setup && mix phx.server` on the database `rephi_e2e` (`E2E_DB_NAME`) and
`yarn dev`, or reuses them when their ports already answer. Or start them yourself:

```bash
DB_NAME=rephi_e2e mix ecto.setup
PORT=4100 DB_NAME=rephi_e2e CORS_ORIGINS=http://localhost:5101 RATE_LIMIT_ENABLED=false mix phx.server
VITE_PORT=5101 VITE_API_URL=http://localhost:4100/api VITE_WS_URL=ws://localhost:4100/socket yarn example:dev
yarn example:e2e
```

Run it against an API nobody else is connected to (the presence check counts every socket).
Arguments go to Playwright: `yarn example:e2e dashboard`, `yarn example:e2e --grep "New role"`,
`yarn example:e2e --ui`. Failures keep a trace and a screenshot in `e2e/.results/`
(`npx playwright show-trace e2e/.results/<test>/trace.zip`).

## Settings

| Variable | Default | |
|----------|---------|-|
| `E2E_BASE_URL` | `http://localhost:5101/app/example/` | The app. |
| `E2E_API_URL` | `http://localhost:4100/api` | The API the app talks to. |
| `E2E_ADMIN_EMAIL` / `E2E_ADMIN_PASSWORD` | `admin@admin.com` / `password123!!` | An administrator (the development seed). |
| `E2E_BROWSER_CHANNEL` | `chrome` | The installed Google Chrome. `chromium` uses Playwright's own build (`npx playwright install chromium` first); `msedge` and other channels work too. |
| `E2E_HEADED` | unset | `1` shows the browser. |
| `E2E_START_STACK` | unset | `1` starts the API and the dev server (see above). |
| `E2E_DB_NAME` | `rephi_e2e` | Database of the API that `E2E_START_STACK` starts. |

## Writing tests

- Import `test` and `expect` from `support/fixtures.ts`. `asAdmin` and `asPlainUser` are pages
  already signed in (the session is put in `localStorage`, no login request); `pageAs(session)`
  opens one for any session, or signed out with `null`. An uncaught error in a page fails the
  test.
- The administrator and plain-user sessions are shared by the whole run: a test that signs out,
  changes a password or deletes a user registers its own account (`api.registerUnique()`).
- Create what a test needs through `support/api.ts` and delete it in a `finally` with `cleanup()`.
- Paths are relative to the app: `appUrl(baseURL, "admin/roles?new=1")`.
