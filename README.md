# Rephi

A production-ready Phoenix boilerplate with JWT authentication, RBAC authorization, WebSocket support, and multi-frontend architecture.

## 🚀 Inicio Rápido

### Prerrequisitos

- **Elixir** 1.14 o superior
- **Erlang** 24 o superior
- **PostgreSQL** 12 o superior
- **Node.js** 18 o superior
- **npm** o **yarn**

### 📥 Instalación Inicial

1. **Clonar el repositorio**
   ```bash
   git clone <repository-url>
   cd rephi
   ```

2. **Configurar variables de entorno**
   ```bash
   cp .env.example .env
   ```
   
   Edita el archivo `.env` con tus configuraciones:
   - Credenciales de base de datos
   - Claves secretas (genera nuevas con `mix phx.gen.secret`)
   - Configuración de puertos y hosts

### 🔧 Configuración del Backend

1. **Instalar dependencias**
   ```bash
   mix deps.get
   ```

2. **Configurar la base de datos**
   ```bash
   mix ecto.create
   mix ecto.migrate
   ```

   O usar el comando de setup completo:
   ```bash
   mix setup
   ```

3. **Iniciar el servidor Phoenix**
   ```bash
   mix phx.server
   ```
   
   O con shell interactivo:
   ```bash
   iex -S mix phx.server
   ```

   El backend estará disponible en `http://localhost:4000`

### 💻 Configuración del Frontend

1. **Navegar al directorio del frontend**
   ```bash
   cd front/rephi-front
   ```

2. **Instalar dependencias**
   ```bash
   npm install
   ```

3. **Iniciar el servidor de desarrollo**
   ```bash
   npm run dev
   ```

   El frontend estará disponible en `http://localhost:5173` (o el puerto configurado)

## 📚 API Documentation

La documentación interactiva de la API está disponible mediante Swagger:

- **Swagger UI**: `http://localhost:4000/api/swagger`
- **Swagger JSON**: `http://localhost:4000/api/swagger/swagger.json`

Para regenerar la documentación después de cambios:
```bash
mix phx.swagger.generate
```

## 🛠️ Comandos Útiles

### Backend
```bash
# Ejecutar pruebas
mix test

# Formatear código
mix format

# Limpiar y reconstruir
mix clean && mix compile

# Resetear base de datos
mix ecto.reset

# Generar documentación Swagger
mix phx.swagger.generate
```

### Frontend
```bash
# Construir para producción
npm run build

# Ejecutar linter
npm run lint

# Verificar tipos TypeScript
npm run typecheck

# Iniciar servidor de producción
npm start
```

## 🏗️ Arquitectura

### Backend (Phoenix/Elixir)
- **API REST** bajo `/api/*`
- **Autenticación JWT** con Guardian
- **WebSockets** con Phoenix Channels
- **Base de datos** PostgreSQL con Ecto
- **Documentación** automática con Phoenix Swagger

### Frontend (Remix/React)
- **SPA Mode** sin SSR
- **Estado Global** con Zustand (persistido)
- **Formularios** con React Hook Form + Zod
- **Estilos** con Tailwind CSS v4
- **Cliente API** con Axios

## 🔐 Autenticación y Autorización

### Autenticación JWT
1. Los usuarios se registran/autentican en `/api/users/register` o `/api/users/login`
2. El JWT se almacena en Zustand y localStorage
3. Axios interceptor añade automáticamente el header `Authorization: Bearer {token}`
4. Los endpoints protegidos requieren autenticación válida

### Sistema de Roles y Permisos (RBAC)

Rephi incluye un sistema completo de control de acceso basado en roles (RBAC) con las siguientes características:

#### 🎭 Roles y Jerarquías
- **Roles jerárquicos**: Los roles pueden heredar permisos de otros roles
- **Roles por defecto**: 
  - `admin` → hereda de `manager`
  - `manager` → hereda de `user`
  - `user` → acceso básico

#### 🔑 Permisos Granulares
Los permisos están organizados por categorías:

- **users:** - Gestión de usuarios (`users:view`, `users:create`, `users:edit`, `users:delete`)
- **roles:** - Gestión de roles (`roles:view`, `roles:create`, `roles:edit`, `roles:delete`, `roles:assign`)
- **permissions:** - Gestión de permisos (`permissions:view`, `permissions:create`, etc.)
- **system:** - Configuración del sistema (`system:settings`, `system:logs`, `system:manage`)

#### 🛡️ Verificaciones de Autorización

**En Controladores:**
```elixir
# Proteger acciones individuales
plug AuthorizationPlug, {:permission, "users:edit"}
plug AuthorizationPlug, {:role, "admin"}
plug AuthorizationPlug, {:any_permission, ["users:create", "users:edit"]}
plug AuthorizationPlug, {:all_permissions, ["users:edit", "system:manage"]}

# Verificaciones manuales
if can?(conn, "users:edit") do
  # Usuario puede editar usuarios
end

if has_role?(conn, "admin") do
  # Usuario tiene rol de admin
end
```

**En el Contexto:**
```elixir
# Verificaciones directas
Authorization.can?(user, "users:edit")
Authorization.has_role?(user, "admin")
Authorization.role_has_permission?(role, permission)

# Verificaciones flexibles
Authorization.can_by?(user: user, permission: "system:manage")
Authorization.can_by?(user: user, role: "admin")

# Obtener datos
Authorization.get_user_roles(user)
Authorization.get_user_permissions(user)
Authorization.get_role_permissions(role)
```

#### 📡 API de Roles y Permisos

**Gestión de Roles:**
```bash
GET    /api/roles              # Listar roles
POST   /api/roles              # Crear rol
GET    /api/roles/:id          # Obtener rol específico
PUT    /api/roles/:id          # Actualizar rol
DELETE /api/roles/:id          # Eliminar rol

# Asignación de roles a usuarios
POST   /api/users/:user_id/roles/:role_id     # Asignar rol
DELETE /api/users/:user_id/roles/:role_id     # Quitar rol
```

**Gestión de Permisos:**
```bash
GET    /api/permissions         # Listar permisos
POST   /api/permissions         # Crear permiso
GET    /api/permissions/:id     # Obtener permiso específico
PUT    /api/permissions/:id     # Actualizar permiso
DELETE /api/permissions/:id     # Eliminar permiso

# Asignación de permisos a roles
POST   /api/roles/:role_id/permissions/:perm_id     # Asignar permiso
DELETE /api/roles/:role_id/permissions/:perm_id     # Quitar permiso
```

**Información del Usuario Actual:**
```bash
GET /api/me  # Incluye roles y permisos del usuario autenticado
```

#### 🌱 Datos Semilla
Al ejecutar `mix ecto.reset` o `mix run priv/repo/seeds.exs`, se crean automáticamente:

- **3 roles** con jerarquía (admin → manager → user)
- **17 permisos** categorizados por funcionalidad
- **Usuario administrador** (`admin@admin.com` / `password123!!`) con rol admin

#### 💡 JWT Integrado
Los tokens JWT incluyen automáticamente:
- Lista de roles del usuario (`"roles": ["admin", "manager"]`)
- Lista de permisos efectivos (`"permissions": ["users:view", "users:create", ...]`)

#### 🔧 Helpers de Autorización
Disponibles en todos los controladores y vistas:
```elixir
can?(conn, "permission:slug")           # ¿Tiene permiso específico?
has_role?(conn, "role_slug")           # ¿Tiene rol específico?
can_any?(conn, ["perm1", "perm2"])     # ¿Tiene alguno de estos permisos?
can_all?(conn, ["perm1", "perm2"])     # ¿Tiene todos estos permisos?
current_user_roles(conn)               # Roles del usuario actual
current_user_permissions(conn)         # Permisos del usuario actual
authorize(conn, permission: "users:edit") # Verificación flexible
```

## 📡 WebSockets

La conexión WebSocket se establece en `ws://localhost:4000/socket` con canales específicos por usuario.

**✅ Seguridad**: Las conexiones WebSocket validan el token JWT antes de permitir la conexión. Los tokens inválidos o ausentes son rechazados automáticamente.

## Testing

```bash
# Run backend tests
mix test

# Run with coverage
mix test --cover
```

## Deployment

### Building for Production

```bash
# Backend
MIX_ENV=prod mix compile
MIX_ENV=prod mix assets.deploy

# Frontends
mix frontends.build
```

### Docker Support

```bash
docker build -t rephi .
docker run -p 4000:4000 rephi
```

## Publishing to Hex.pm

1. Update the version in `mix.exs`
2. Update `CHANGELOG.md` with release notes
3. Ensure tests pass: `mix test`
4. Create git tag: `git tag -a v0.1.0 -m "Release v0.1.0"`
5. Publish: `mix hex.publish`

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.