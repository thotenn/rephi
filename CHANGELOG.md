# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[0.0.2]: https://github.com/thotenn/rephi/releases/tag/v0.0.2