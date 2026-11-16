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
  /** Until changed, the API answers 403 to everything but `/me`, the password change and logout. */
  must_change_password: boolean;
  roles: Role[];
  permissions: Permission[];
}

export interface AuthSession {
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

export interface ChangePasswordParams {
  current_password: string;
  password: string;
  password_confirmation: string;
}

export type SessionEndReason =
  | "logout"
  | "unauthorized";
