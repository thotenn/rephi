# Protección de Rutas y Redirección

## Cómo funciona

Cuando un visitante sin sesión entra a una ruta protegida:

1. **`ProtectedRoute`** detecta que no hay sesión (`useAuthStore().isAuthenticated`).
2. Redirige a `/login` con la ruta pedida en el state de navegación:
   `state={{ from: "/pages/profile" }}`.
3. La página de login muestra "You need to login to access that page.".
4. Al iniciar sesión, el store cambia y **`PublicRoute`** (que envuelve al login) navega a
   `state.from`, o a `/home` si no hay. Es la única navegación: `useLogin` no navega.

Cuando la sesión termina **estando en una página protegida** (logout, token vencido o revocado,
cierre de sesión en otra pestaña), `ProtectedRoute` redirige al login con
`state={{ sessionEnded: "logout" | "unauthorized" }}` en vez de `from`: el login muestra "You have
been signed out." o "Your session has ended. Please sign in again." y, al volver a entrar, arranca
desde `/home`.

## Flujo de ejemplo

```
Visitante entra a /pages/profile (sin sesión)
  ↓
ProtectedRoute → /login con state.from = "/pages/profile"
  ↓
Login muestra "You need to login to access that page."
  ↓
login() guarda la sesión → PublicRoute navega a /pages/profile
```

## Componentes involucrados

### `ProtectedRoute` (`src/components/bedrock/routes/ProtectedRoute.tsx`)

```tsx
const state: LoginLocationState = sessionEndReason
  ? { sessionEnded: sessionEndReason }
  : { from: `${location.pathname}${location.search}` };
return <Navigate to={ROUTE_PATHS.auth.login} replace state={state} />;
```

No escribe nada durante el render: todo viaja en el state de la navegación.

### `PublicRoute` (`src/components/bedrock/routes/PublicRoute.tsx`)

```tsx
if (isAuthenticated) {
  return <Navigate to={safeRedirectTarget(location.state) ?? ROUTE_PATHS.home} replace />;
}
```

`safeRedirectTarget` (`src/utils/redirect.ts`) sólo acepta rutas internas (empiezan con `/`,
no con `//`).

### Página de login (`src/routes/login.tsx`)

```tsx
const state = (location.state ?? {}) as LoginLocationState;
const notice = state.sessionEnded
  ? sessionNotices[state.sessionEnded]
  : state.from
    ? "You need to login to access that page."
    : null;
```

Los errores del servidor se muestran tal cual llegan: credenciales inválidas (401), 429 con
"Too many attempts. Try again in N seconds.", o errores por campo bajo cada input.

## Casos de uso

1. **Acceso directo a ruta protegida**: `/pages/profile` → `/login` → `/pages/profile`.
2. **Logout**: `POST /api/users/logout` y luego `/login` con "You have been signed out.".
3. **Token revocado o vencido** (logout en otro dispositivo, cambio de contraseña, 24 h): el
   primer 401 —o el cierre del socket por el servidor— termina la sesión y vuelve al login.
4. **Deep linking**: compartir un enlace a una ruta protegida funciona.

## Notas

- `replace` evita volver al login con "atrás" después de autenticarse.
- Los permisos se chequean con `PermissionRoute` (`meta.permission`); quien no los tiene ve la
  pantalla de acceso denegado, sin redirección.
