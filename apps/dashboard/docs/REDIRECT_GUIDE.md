# Protección de Rutas y Redirección

## Cómo funciona el sistema de redirección

Cuando un usuario no autenticado intenta acceder a una ruta protegida:

1. **ProtectedRoute** detecta que no hay autenticación
2. Guarda la ruta actual en el state: `state={{ from: location.pathname }}`
3. Redirige a `/login`
4. El componente Login muestra un mensaje informativo
5. Después del login exitoso, el usuario es redirigido a la ruta original

## Flujo de ejemplo

```
Usuario visita /pages/profile (sin autenticación)
  ↓
ProtectedRoute redirige a /login con state.from = "/pages/profile"
  ↓
Usuario ve el mensaje "You need to login to access that page"
  ↓
Usuario inicia sesión
  ↓
useLogin detecta state.from y redirige a /pages/profile
```

## Componentes involucrados

### ProtectedRoute
```typescript
// Guarda la ruta intentada
return <Navigate 
  to={ROUTES.auth.login} 
  state={{ from: location.pathname }} 
  replace 
/>;
```

### useLogin Hook
```typescript
// Recupera la ruta y redirige después del login
const from = location.state?.from || urls.home;
navigate(from, { replace: true });
```

### Login Component
```typescript
// Muestra mensaje si hay redirección pendiente
{from && (
  <div className="rounded-md bg-blue-50 p-4">
    <div className="text-sm text-blue-800">
      You need to login to access that page.
    </div>
  </div>
)}
```

## Debug

El componente DebugAuth muestra:
- La ruta actual
- Estado de autenticación
- Si hay una redirección pendiente (state.from)

## Casos de uso

1. **Acceso directo a ruta protegida**: `/pages/profile` → `/login` → `/pages/profile`
2. **Navegación normal**: Usuario logueado puede navegar libremente
3. **Logout y acceso**: Después de logout, intentar acceder redirige a login
4. **Deep linking**: Compartir enlaces de rutas protegidas funciona correctamente

## Notas importantes

- El `replace: true` evita que el usuario pueda volver atrás al login después de autenticarse
- Si no hay ruta pendiente, redirige a `/home` por defecto
- El state se limpia automáticamente después de la navegación
