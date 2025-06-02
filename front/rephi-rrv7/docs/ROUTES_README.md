# Sistema de Rutas Mejorado

## Estructura Actual

```
src/
├── config/
│   ├── routes.ts              # Configuración principal de rutas
│   └── routes/
│       └── modules.example.ts # Ejemplos de módulos de rutas
├── router.tsx                 # Router principal
└── routes/                    # Componentes de las páginas
```

## Cómo Agregar Nuevas Rutas

### 1. Ruta Simple

Edita `src/config/routes.ts` y agrega tu ruta en la sección correspondiente:

```typescript
// En la sección dashboardRoutes
{
  path: "nueva-pagina",
  element: lazy(() => import("../routes/nueva-pagina")),
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
      element: lazy(() => import("../routes/seccion/index")),
    },
    {
      path: "subseccion",
      element: lazy(() => import("../routes/seccion/subseccion")),
    },
  ],
}
```

### 3. Módulo de Rutas Completo

Para secciones grandes, crea un archivo separado:

1. Crea `src/config/routes/mi-modulo.routes.ts`:

```typescript
import { lazy } from "react";
import type { RouteConfig } from "../routes";

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

### Usando las constantes ROUTES

```typescript
import { ROUTES } from "~/router";
import { Link } from "react-router-dom";

// En tu componente
<Link to={ROUTES.dashboard.profile}>Ir al Perfil</Link>
```

### Usando navegación programática

```typescript
import { useNavigate } from "react-router-dom";
import { ROUTES } from "~/router";

function MyComponent() {
  const navigate = useNavigate();
  
  const handleClick = () => {
    navigate(ROUTES.dashboard.home);
  };
  
  return <button onClick={handleClick}>Ir a Home</button>;
}
```

## Ejemplo Completo: Agregar Módulo de Inventario

1. Crea `src/config/routes/inventory.routes.ts`:

```typescript
import { lazy } from "react";
import type { RouteConfig } from "../routes";

export const inventoryRoutes: RouteConfig[] = [
  {
    path: "inventario",
    children: [
      {
        index: true,
        element: lazy(() => import("../../routes/inventario/dashboard")),
        meta: {
          title: "Dashboard Inventario",
          requireAuth: true,
        },
      },
      {
        path: "productos",
        element: lazy(() => import("../../routes/inventario/productos")),
        meta: {
          title: "Productos",
          requireAuth: true,
        },
      },
      {
        path: "categorias",
        element: lazy(() => import("../../routes/inventario/categorias")),
        meta: {
          title: "Categorías",
          requireAuth: true,
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

3. Agrega las constantes en `src/router.tsx` (opcional):

```typescript
export const ROUTES = {
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
3. **Metadata**: Incluye `title` y `requireAuth` en meta
4. **Constantes**: Usa `ROUTES` para evitar strings hardcodeados
5. **Tipos**: TypeScript te ayudará con autocompletado

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
├── admin/                # Módulo admin
│   ├── dashboard.tsx
│   ├── users.tsx
│   └── settings.tsx
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

Este sistema te permite mantener las rutas organizadas y escalables mientras el proyecto crece.
