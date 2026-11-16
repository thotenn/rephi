/** A role as the session and the user listings describe it. */
export interface Role {
  id: number;
  name: string;
  slug: string;
}

/** A permission as the session and the user listings describe it. */
export interface Permission {
  id: number;
  name: string;
  slug: string;
}

/**
 * The signed-in user, as returned by register, login, `GET /api/me` and
 * `PUT /api/me/password`.
 */
export interface User {
  id: number;
  /** Normalized by the server: trimmed and lower-cased. */
  email: string;
  /**
   * An administrator reset the password: until the user sets a new one
   * (`changePassword`), the API refuses everything but `/me`, the password
   * change and logout (403). Send the user to the password form.
   */
  must_change_password: boolean;
  /** Roles assigned to the user (not the ones it only inherits). */
  roles: Role[];
  /** Effective permissions: direct, through roles and inherited. Authorize the UI with these. */
  permissions: Permission[];
}

/** A new session: what register, login and a password change return. */
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

/** Why the session ended (see `onSessionEnd`). */
export type SessionEndReason =
  /** The user signed out, here or in another tab. */
  | "logout"
  /** The server rejected the token (expired, revoked elsewhere, user deleted...). */
  | "unauthorized";
