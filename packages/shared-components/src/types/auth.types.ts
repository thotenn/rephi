export interface Role {
  id: number;
  name: string;
  slug: string;
}

export interface Permission {
  id: number;
  name: string;
  slug: string;
}

export interface User {
  id: number;
  email: string;
  roles?: Role[];
  permissions?: Permission[];
  /** Creation timestamp as sent by the Phoenix API (Ecto's `inserted_at`). */
  inserted_at?: string;
  /** @deprecated The API never sends this field; use `inserted_at`. */
  created_at?: string;
  updated_at?: string;
}

export interface AuthResponse {
  user: User;
  token: string;
}

export interface LoginCredentials {
  email: string;
  password: string;
}

export interface RegisterCredentials {
  email: string;
  password: string;
  password_confirmation: string;
}
