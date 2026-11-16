# @rephi/shared-components

The one place where the Rephi frontends talk to the Phoenix backend: the HTTP client, the
session, the Phoenix socket and channels, permission checks and the types of the API contract.
`apps/example` (Vite SPA) and `apps/example-astro` (Astro islands) both use it.

The library is built to `dist/` (ESM + CommonJS + `.d.ts`); the apps import the build, so run
`yarn shared:build` before starting or building an app. `react`, `phoenix`, `axios` and `zustand`
are not bundled: they resolve from the app.

## Configuration

Nothing is inlined when the library is built. Each app calls `configureRephi()` once, before the
first request or socket connection, with values from its own environment:

```ts
import { configureRephi } from "@rephi/shared-components";

configureRephi({
  apiUrl: "https://api.example.com/api", // REST API base URL
  wsUrl: "wss://api.example.com/socket", // Phoenix socket endpoint
  debug: import.meta.env.DEV,            // socket + library logs in the console
});
```

| Key | Default | Notes |
|---|---|---|
| `apiUrl` | `/api` | Same origin: right when Phoenix serves the app at `/app/<name>/` |
| `wsUrl` | `/socket` | Same origin |
| `debug` | `false` | Replaces the old `process.env.NODE_ENV` checks, which needed a bundler define |

`getRephiConfig()` returns what is in effect. Keys left out keep their value; calling it again
is safe (the axios instance follows the new `apiUrl` at once, the socket uses a new `wsUrl` on
its next `connect()`). `apps/example` does it in `src/lib/rephi.ts` (imported first by
`main.tsx`), `apps/example-astro` in `src/lib/rephi.ts` (every island imports the library through
it).

The library can be imported where there is no browser (SSR, prerendering): storage is only
touched when it exists, and the session then lives in memory.

## The API contract in short

- Success bodies are `{"data": ...}`; lists are `{"data": [...], "meta": {page, page_size, total, total_pages}}`
  (default 50 per page, at most 100).
- Errors are `{"errors": {"detail": "..."}}` or, for validation (422),
  `{"errors": {"<field>": ["...", ...]}}`.
- Status conventions: 401 session gone, 403 not allowed to do *this*, 404, 409 conflicts with the
  state of the data (system role, last admin...), 422 invalid field, 429 rate limited
  (`retry-after` header).
- Login, register, `GET /api/me` and `PUT /api/me/password` describe the user the same way:
  `{id, email, roles, permissions}`; `roles` are the assigned ones, `permissions` the effective
  ones (direct + through roles + inherited). Authorize the UI by permission.
- Tokens last 24 h and can be revoked (logout, password change, user deleted): any 401 means the
  session is over.

## HTTP client and errors

```ts
import { api, describeError, getErrorMessage, isApiError } from "@rephi/shared-components";

try {
  const { data } = await api.get("/roles/1");   // Authorization: Bearer <token> is added
  console.log(data.data);
} catch (error) {
  const { message, fieldErrors, status } = describeError(error);
  // message:     "Slug has already been taken" / "System roles cannot be deleted" /
  //              "Too many attempts. Try again in 42 seconds." / "Could not reach the server..."
  // fieldErrors: { slug: ["has already been taken"] } for a 422, {} otherwise
}
```

Every failed request rejects with an **`ApiError`** (`status`, `detail`, `fieldErrors`,
`retryAfter`, `hasFieldErrors`, and a `message` that can be shown as is). Helpers:
`describeError(error, fallback?)` → `{message, fieldErrors, status}`, `getErrorMessage(error,
fallback?)`, `getFieldErrors(error)`, `isApiError(error)`, `humanizeField("password_confirmation")`
→ `"Password confirmation"`, `fieldErrorsToMessage(fieldErrors)`.

**401 handling.** A 401 on a request that carried the *current* token ends the session:
`endSession("unauthorized")` clears the store, closes the socket and notifies `onSessionEnd`
listeners. A late 401 for a token that was already replaced (re-login, password change) is
ignored, and so are the 401s of requests in flight while `logout()` runs.

## Session

```ts
import {
  login, register, logout, fetchMe, changePassword,
  useAuthStore, onSessionEnd,
} from "@rephi/shared-components";

await login({ email, password });            // stores user + token (no /me round trip)
await register({ email, password, password_confirmation }); // the user gets the default role
await fetchMe();                             // refreshes roles/permissions in the store
await changePassword({ current_password, password, password_confirmation });
// ^ the server revokes every token of the user and returns a new session, which replaces
//   the stored one; the socket reconnects with the new token
await logout();                              // POST /api/users/logout, then clears locally (always)

const { user, token, isAuthenticated, sessionEndReason } = useAuthStore.getState();

const stop = onSessionEnd((reason) => {      // "logout" | "unauthorized"
  queryClient.clear();
  if (reason === "unauthorized") toast.error("Your session has ended.");
});
```

- `useAuthStore` (zustand, persisted in `localStorage` under `auth-storage`, `AUTH_STORAGE_KEY`):
  `user`, `token`, `isAuthenticated`, `sessionEndReason` (not persisted: lets a login page say
  "you signed out" vs "your session expired"), `setSession(user, token)`, `setUser(user)`,
  `clear(reason?)`. Tabs stay in sync: signing out in one tab signs out the others.
- `startSession(user, token)` / `endSession(reason)` are the low-level pieces the calls above use.
- Navigation is left to the app: guards that follow `isAuthenticated` cover every way a session
  ends (logout, 401, another tab).

## Socket and channels

```ts
import {
  PhoenixSocket, useChannel, useChannelEvent, usePhoenixSocket,
  LOBBY_TOPIC, NOTIFICATION_EVENT, userTopic, type RephiNotification,
} from "@rephi/shared-components";

// Whoever owns the session opens and closes the socket:
useEffect(() => {
  if (!isAuthenticated) return;
  PhoenixSocket.connect();
  return () => PhoenixSocket.disconnect();
}, [isAuthenticated]);

// Anywhere below:
const lobby = useChannel(LOBBY_TOPIC);                       // { channel, connected, error, presences }
const mine = useChannel(user ? userTopic(user.id) : null);   // notifications for this user only
useChannelEvent<RephiNotification>(lobby.channel, NOTIFICATION_EVENT, (n) => {
  toast(`${n.message} — ${n.from?.email ?? "system"}`);      // render as text, never HTML
});
```

- **`PhoenixSocket`** is the app's only socket. The token travels as Phoenix's `authToken` (in
  the `Sec-WebSocket-Protocol` header, never in the URL) and is read from the store on every
  (re)connect. `connect()` reuses the socket while it is open, connecting or reconnecting (never
  two transports) and returns `null` without a session; `disconnect()`, `reconnect()`,
  `getSocket()`, `getStatus()` (`"idle" | "connecting" | "open" | "closed"`), `isConnected()`,
  `subscribe(listener)`, `onDrop(listener)`.
- **Server-side disconnects.** The server closes a user's sockets on logout (any device), password
  change or deletion. When the socket drops without `disconnect()`, the library checks the
  session once with `GET /api/me`: a 401 ends it (the app sees `onSessionEnd("unauthorized")` and
  returns to the login page); anything else leaves Phoenix reconnecting. A password change made
  through `changePassword()` is not taken for a lost session.
- **`useChannel(topic, { params?, enabled? })`** joins `topic` as soon as a socket exists and
  leaves it on unmount or when `topic` / `params` change (params are compared by value).
  `connected` is true while joined and goes false when the socket drops; Phoenix rejoins on
  reconnect. A join refused by the server (`{reason: "unauthorized"}` for another user's
  `user:<id>`) is reported in `error` and not retried. Join each topic in **one place** per page:
  a second join of the same topic on the same socket evicts the first.
- **`useChannelEvent(channel, event, handler)`** binds a handler (always the latest one) and
  unbinds it on cleanup.
- **`usePhoenixSocket()`** → `{socket, status, connected}`.
- Topics: `LOBBY_TOPIC` (`"user:lobby"`, broadcasts), `userTopic(id)` (`"user:<id>"`, only that
  user may join). Event: `NOTIFICATION_EVENT` (`"new_notification"`), payload
  `RephiNotification` = `{message, timestamp, type, from: {id, email} | null}`. Clients cannot
  broadcast over the socket: `broadcastNotification(message)` (`POST /api/notifications/broadcast`)
  needs the `notifications:broadcast` permission; `sendTestNotification(message)`
  (`POST /api/notifications/me`) is open to every signed-in user and reaches only the caller's
  `user:<id>` topic (a 429 past 5 a minute by default). Both resolve to the notification sent.
- **Presence.** The server tracks every lobby socket with Phoenix Presence. `useChannel` keeps
  `presences` (`[{key, metas}]`, one entry per user; `null` until the first `presence_state`)
  current from `presence_state` / `presence_diff`, bound before the join so the first state is
  never missed. `presenceCounts(lobby.presences)` → `{online_users, connections}` or `null`.

## Dashboard

`fetchDashboard()` → `DashboardStats` (`GET /api/dashboard`):
`{users: {total}, notifications: {sent_total, sent_by_me}, sessions: {online_users, connections}}`.
`users.total` is `null` without `users:view`, `notifications.sent_total` without
`notifications:broadcast`: hide those counters rather than showing them as 0.

## Permissions (UI only — the server authorizes every request)

```tsx
import { usePermissions, userCan, PermissionGuard } from "@rephi/shared-components";

const { can, canAny, canAll, hasRole, permissions, roles } = usePermissions();
can("users:view");                        // effective permissions, inheritance included
hasRole("admin");                         // assigned roles only (not inherited ones)
userCan(user, "notifications:broadcast"); // plain function form

<PermissionGuard permissions={["users:edit"]} fallback={<p>Read only</p>}>
  <EditButton />
</PermissionGuard>
```

`AuthGuard` (`isAuthenticated`, `fallback`, `redirectTo`, `onUnauthorized`) remains for apps
without a router of their own.

## Pagination

```ts
import { fetchPage, fetchAllPages, describePage, hasNextPage, MAX_PAGE_SIZE } from "@rephi/shared-components";

const page = await fetchPage<Role>("/roles", { page: 2, page_size: 20 }); // { data, meta }
describePage(page.meta);              // "21–40 of 57"
hasNextPage(page.meta);               // meta.page < meta.total_pages
const all = await fetchAllPages<Role>("/roles"); // every page, 100 at a time (small catalogs)
```

Types: `PaginatedResponse<T>`, `PageMeta`, `PageParams`.

## Route helpers

`setRedirectPath` / `getRedirectPath` / `clearRedirectPath` keep a "go back here after login"
path in session storage (the Astro app uses them; the SPA carries it in the router state).
`filterRoutesByPermissions(routes, {isAuthenticated, permissions, roles?})` and
`createProtectedRoute(path, options)` build menus from a route list.

## Types

`User`, `Role`, `Permission`, `AuthSession`, `LoginCredentials`, `RegisterCredentials`,
`ChangePasswordParams`, `SessionEndReason`, `ApiResponse<T>`, `ApiErrorBody`, `FieldErrors`,
`PaginatedResponse<T>`, `PageMeta`, `PageParams`, `RephiNotification`, `DashboardStats`,
`OnlineCounts`, `PresenceEntry`.

## Development

```bash
yarn shared:build                                  # build once
yarn workspace @rephi/shared-components dev        # rebuild on change
yarn workspace @rephi/shared-components lint
yarn workspace @rephi/shared-components typecheck
```

The build writes `dist/index.mjs` (ESM), `dist/index.js` (CommonJS) and the `.d.ts` files, which
`tsc` emits at the end of every Vite build (also in watch mode).
