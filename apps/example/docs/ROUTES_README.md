# Sistema de Rutas Mejorado

## Estructura Actual

```
src/
├── config/
│   └── routes.ts              # Tabla de rutas: ROUTE_PATHS, ADMIN_PERMISSIONS y los arrays de rutas
├── router.tsx                 # Router principal (guards según `meta`)
└── routes/                    # Componentes de las páginas
```

Las rutas son relativas al `basename` del router (`/app/example`, el `base` de Vite). Ver
[ROUTER_GUIDE.md](ROUTER_GUIDE.md) para los guards (`requireAuth`, `permission`, `publicOnly`).

## Cómo Agregar Nuevas Rutas

### 1. Ruta Simple

Edita `src/config/routes.ts` y agrega tu ruta en la sección correspondiente:

```typescript
// En la sección dashboardRoutes
{
  path: "nueva-pagina",
  element: lazy(() => import("~/routes/nueva-pagina")),
  meta: {
    title: "Nueva Página",
    requireAuth: true,
  },
}
```

### 2. Ruta con Subrutas

```typescript
{
  path: "seccion",
  children: [
    {
      index: true,
      element: lazy(() => import("~/routes/seccion/index")),
    },
    {
      path: "subseccion",
      element: lazy(() => import("~/routes/seccion/subseccion")),
    },
  ],
}
```

### 3. Módulo de Rutas Completo

Para secciones grandes, crea un archivo separado:

1. Crea `src/config/routes/mi-modulo.routes.ts`:

```typescript
import { lazy } from "react";
import type { RouteConfig } from "~/config/routes";

export const miModuloRoutes: RouteConfig[] = [
  {
    path: "mi-modulo",
    children: [
      // tus rutas aquí
    ],
  },
];
```

2. Importa y agrega en `src/config/routes.ts`:

```typescript
import { miModuloRoutes } from "./routes/mi-modulo.routes";

// En allRoutes:
export const allRoutes: RouteConfig[] = [
  ...publicRoutes,
  ...authRoutes,
  ...dashboardRoutes,
  ...miModuloRoutes, // Agrega aquí
];
```

## Navegación

### Usando las constantes ROUTE_PATHS

```typescript
import { Link } from "react-router";
import { ROUTE_PATHS } from "~/config/routes";

// En tu componente
<Link to={ROUTE_PATHS.pages.profile}>Ir al Perfil</Link>
```

### Usando navegación programática

```typescript
import { useNavigate } from "react-router";
import { ROUTE_PATHS } from "~/config/routes";

function MyComponent() {
  const navigate = useNavigate();

  const handleClick = () => {
    navigate(ROUTE_PATHS.home);
  };
  
  return <button onClick={handleClick}>Ir a Home</button>;
}
```

## Ejemplo Completo: Agregar Módulo de Inventario

1. Crea `src/config/routes/inventory.routes.ts`:

```typescript
import { lazy } from "react";
import type { RouteConfig } from "~/config/routes";

export const inventoryRoutes: RouteConfig[] = [
  {
    path: "inventario",
    children: [
      {
        index: true,
        element: lazy(() => import("~/routes/inventario/dashboard")),
        meta: {
          title: "Dashboard Inventario",
          requireAuth: true,
        },
      },
      {
        path: "productos",
        element: lazy(() => import("~/routes/inventario/productos")),
        meta: {
          title: "Productos",
          requireAuth: true,
        },
      },
      {
        path: "categorias",
        element: lazy(() => import("~/routes/inventario/categorias")),
        meta: {
          title: "Categorías",
          // Sólo para quien tenga el permiso (y sesión iniciada).
          permission: "inventory:manage",
        },
      },
    ],
  },
];
```

2. Actualiza `src/config/routes.ts`:

```typescript
import { inventoryRoutes } from "./routes/inventory.routes";

export const allRoutes: RouteConfig[] = [
  ...publicRoutes,
  ...authRoutes,
  ...dashboardRoutes,
  ...inventoryRoutes,
];
```

3. Agrega las constantes en `ROUTE_PATHS` de `src/config/routes.ts` (opcional):

```typescript
export const ROUTE_PATHS = {
  // ... rutas existentes
  inventory: {
    home: "/inventario",
    products: "/inventario/productos",
    categories: "/inventario/categorias",
  },
} as const;
```

## Mejores Prácticas

1. **Lazy Loading**: Siempre usa `lazy()` para cargar componentes
2. **Organización**: Agrupa rutas relacionadas en módulos
3. **Metadata**: Incluye `title` y `requireAuth` (o `permission`) en meta
4. **Constantes**: Usa `ROUTE_PATHS` para evitar strings hardcodeados
5. **Permisos, no roles**: protegé por permiso (`meta.permission`), no por el slug de un rol
6. **Tipos**: TypeScript te ayudará con autocompletado

## Estructura de Carpetas Recomendada

```
src/routes/
├── index.tsx              # Página principal
├── login.tsx             # Login
├── register.tsx          # Registro
├── home.tsx              # Dashboard home
├── pages/                # Páginas generales
│   ├── profile/
│   └── dashboard/
├── admin/                # Módulo admin (users/, roles/, permissions/)
└── inventario/           # Módulo inventario
    ├── dashboard.tsx
    ├── productos.tsx
    └── categorias.tsx
```

## Notas Importantes

- Las rutas se procesan automáticamente con Suspense para lazy loading
- El ErrorBoundary captura errores en cualquier ruta
- Las rutas públicas no requieren autenticación
- Las rutas con `requireAuth: true` necesitan que el usuario esté logueado
- Las rutas con `permission: "x:y"` necesitan además ese permiso; si no, muestran "Access Denied"
- Una ruta no puede terminar en algo con forma de extensión (`/users/john.doe`): Phoenix la
  trata como archivo y responde 404

Este sistema te permite mantener las rutas organizadas y escalables mientras el proyecto crece.
