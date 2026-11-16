export const API_URL = (process.env.E2E_API_URL ?? "http://localhost:4110/api").replace(/\/+$/, "");

export const ADMIN = {
  email: process.env.E2E_ADMIN_EMAIL ?? "admin@admin.com",
  password: process.env.E2E_ADMIN_PASSWORD ?? "password123!!",
};

export const TEST_PASSWORD = "e2e-password-1";

interface Summary {
  id: number;
  name: string;
  slug: string;
}

export interface SessionUser {
  id: number;
  email: string;
  roles: Summary[];
  permissions: Summary[];
}

export interface Session {
  token: string;
  user: SessionUser;
}

export interface Role extends Summary {
  description: string | null;
  is_system: boolean;
}

export class ApiError extends Error {
  constructor(
    readonly status: number,
    readonly body: unknown,
    request: string
  ) {
    super(
      status === 429
        ? `${request} -> 429: the API rate-limited the tests. Start it with RATE_LIMIT_ENABLED=false (see the README).`
        : `${request} -> ${status} ${JSON.stringify(body)}`
    );
  }
}

async function call<T>(method: string, path: string, options: { token?: string; body?: unknown } = {}): Promise<T> {
  const response = await fetch(`${API_URL}${path}`, {
    method,
    headers: {
      accept: "application/json",
      ...(options.body ? { "content-type": "application/json" } : {}),
      ...(options.token ? { authorization: `Bearer ${options.token}` } : {}),
    },
    body: options.body ? JSON.stringify(options.body) : undefined,
  });
  const text = await response.text();
  const body: unknown = text ? JSON.parse(text) : null;
  if (!response.ok) throw new ApiError(response.status, body, `${method} ${path}`);
  return (body as { data: T } | null)?.data as T;
}

export function unique(prefix: string): string {
  return `${prefix}-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 7)}`;
}

export const api = {
  login: (email: string, password: string) => call<Session>("POST", "/users/login", { body: { email, password } }),

  register: (email: string, password = TEST_PASSWORD) =>
    call<Session>("POST", "/users/register", {
      body: { email, password, password_confirmation: password },
    }),

  registerUnique: (prefix = "e2e-user") => api.register(`${unique(prefix)}@example.com`),

  createRole: (token: string, role: { name: string; slug: string; description?: string }) =>
    call<Role>("POST", "/roles", { token, body: { role } }),

  roles: (token: string) => call<Role[]>("GET", "/roles?page_size=100", { token }),

  roleBySlug: async (token: string, slug: string) => {
    const role = (await api.roles(token)).find((candidate) => candidate.slug === slug);
    if (!role) throw new Error(`No role with the slug ${slug}`);
    return role;
  },

  deleteRole: (token: string, id: number) => call<void>("DELETE", `/roles/${id}`, { token }),

  deleteUser: (token: string, id: number) => call<void>("DELETE", `/users/${id}`, { token }),
};

export async function cleanup(fn: () => Promise<unknown>): Promise<void> {
  try {
    await fn();
  } catch (error) {
    if (!(error instanceof ApiError && error.status === 404)) console.warn(`cleanup: ${String(error)}`);
  }
}
