# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- Backend toolchain upgraded to Elixir 1.20.5 and Erlang/OTP 29.1.2 (`.tool-versions`).
  The project and the `rephi_new` installer now require Elixir `~> 1.19`
- All Hex dependencies updated to their latest releases: Phoenix 1.8.16, Phoenix LiveView 1.2,
  Phoenix LiveDashboard 0.9, Ecto / Ecto SQL 3.14, Plug 1.20, Bandit 1.14, Gettext 1.0, Guardian 2.5,
  Swoosh 1.29, Finch 0.24, DNSCluster 0.3, Telemetry Metrics 1.2, Phoenix Swagger 0.8.5, ExDoc 0.40
- Logger configuration moved from the legacy `config :logger, :console` key to `:default_formatter`
- `swagger.json` no longer contains `null` placeholder fields next to each `$ref`
- Frontend toolchain upgraded: Node.js 26 LTS (minimum 22.22), Yarn 4.18, Vite 8, TypeScript 7,
  ESLint 10, React 19.3, React Router 8, Zod 4, `@hookform/resolvers` 7, Tailwind CSS 4.3 and
  the `phoenix` client 1.8
- TypeScript 7 (`tsc`) is installed next to the TypeScript 6 API, which lint tooling still
  needs, through the `@typescript/native` and `typescript` npm aliases
- ESLint uses flat config (`eslint.config.js`) in every workspace, and `yarn lint` now covers
  `@rephi/shared-components` as well
- `@rephi/shared-components` declares `axios` and `zustand` as dependencies and no longer
  bundles them or the React JSX runtime
- Imports from `react-router-dom` are now `react-router` (`RouterProvider` comes from
  `react-router/dom`)

### Removed
- `plug_cowboy`: the endpoint has always been served by Bandit, so Cowboy was never started
- `poison` and `ex_json_schema`: both are optional in Phoenix Swagger 0.8.5. Swagger documents are
  now encoded with Jason (`config :phoenix_swagger, json_library: Jason`)
- `react-router-dom`, `vite-tsconfig-paths`, `vite-plugin-dts`, `autoprefixer`, `clsx` and the
  unused `tailwind.config.mjs`
- `eslint-plugin-react`, `eslint-plugin-jsx-a11y` and `eslint-plugin-import`, replaced by
  `@eslint-react/eslint-plugin`, `eslint-plugin-jsx-a11y-x` and `eslint-plugin-import-x`
- The `./styles` export of `@rephi/shared-components`, which pointed to a file that was never built

### Fixed
- `Phoenix.CodeReloader` is registered as a Mix listener, as Phoenix requires on Elixir 1.18+
- Compiler and type-checker warnings reported by Elixir 1.20
- `yarn lint` runs again: the legacy `.eslintrc.json` and the `--ignore-path` flag had stopped
  working with ESLint 9
- Type declarations of `@rephi/shared-components` no longer contain unresolved `@/` path aliases

## [0.1.0] - 2025-06-23

### Added
- New Mix task `mix rephi.gen.frontend [front_name]` for generating frontend applications
  - Automatically copies the example frontend template
  - Updates router.ex with the new frontend route
  - Streamlines the process of adding new frontend applications to the multi-frontend architecture

### Fixed
- Router catch-all routes moved to end to prevent unreachable routes warning

## [0.0.2] - 2024-06-22

### Added
- Initial release
- JWT authentication system with Guardian
- Complete RBAC (Role-Based Access Control) implementation
- WebSocket support with Phoenix Channels
- Multi-frontend architecture support
- Swagger/OpenAPI documentation
- CSRF protection for SPAs
- Default roles and permissions seeding
- Frontend build integration with Mix tasks
- Dashboard, Admin, E-commerce, and Landing page structure

### Security
- JWT tokens include user roles and permissions
- CSRF token injection in SPA HTML
- WebSocket connections validate JWT tokens
- Hierarchical permission system

[0.1.0]: https://github.com/thotenn/rephi/releases/tag/v0.1.0
[0.0.2]: https://github.com/thotenn/rephi/releases/tag/v0.0.2