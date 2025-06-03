# Rephi

Rephi es una aplicación full-stack que combina un backend Phoenix/Elixir con un frontend Remix/React, ofreciendo autenticación JWT y comunicación en tiempo real mediante WebSockets.

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

## 🔐 Autenticación

1. Los usuarios se registran/autentican en `/api/users/register` o `/api/users/login`
2. El JWT se almacena en Zustand y localStorage
3. Axios interceptor añade automáticamente el header `Authorization: Bearer {token}`
4. Los endpoints protegidos requieren autenticación válida

## 📡 WebSockets

La conexión WebSocket se establece en `ws://localhost:4000/socket` con canales específicos por usuario.

**✅ Seguridad**: Las conexiones WebSocket validan el token JWT antes de permitir la conexión. Los tokens inválidos o ausentes son rechazados automáticamente.

## 🧪 Testing

### Backend
```bash
mix test
```

### Frontend
No hay framework de pruebas configurado actualmente.

## 📝 Variables de Entorno

Las principales variables de entorno incluyen:

- `DATABASE_URL`: URL completa de PostgreSQL
- `SECRET_KEY_BASE`: Clave secreta para Phoenix (mínimo 64 caracteres)
- `GUARDIAN_SECRET_KEY`: Clave secreta para JWT
- `PHX_HOST`: Host del servidor Phoenix
- `PORT`: Puerto del servidor
- `FRONTEND_URL`: URL del frontend (para CORS)

Ver `.env.example` para la lista completa.

## 🚢 Despliegue

Para producción:

1. Configura las variables de entorno apropiadas
2. Compila los assets del frontend: `npm run build`
3. Ejecuta las migraciones: `MIX_ENV=prod mix ecto.migrate`
4. Inicia el servidor: `MIX_ENV=prod mix phx.server`

## 📖 Recursos

- [Phoenix Framework](https://www.phoenixframework.org/)
- [Remix Documentation](https://remix.run/docs)
- [Guardian JWT](https://github.com/ueberauth/guardian)
- [Phoenix Swagger](https://github.com/xerions/phoenix_swagger)