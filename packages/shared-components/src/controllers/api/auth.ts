import { debugLog } from "../../config";
import { isApiError } from "../../errors";
import {
  endSession,
  isRotatingToken,
  startSession,
  whileRotatingToken,
  whileSigningOut,
} from "../../session";
import { useAuthStore } from "../../stores/auth.store";
import type {
  ApiResponse,
  AuthSession,
  ChangePasswordParams,
  LoginCredentials,
  RegisterCredentials,
  User,
} from "../../types";
import api from "./api";
import PhoenixSocket from "./socket";

/** Paths of the auth endpoints, relative to `apiUrl`. */
export const AUTH_ENDPOINTS = {
  login: "/users/login",
  register: "/users/register",
  logout: "/users/logout",
  me: "/me",
  password: "/me/password",
} as const;

/**
 * Signs in and stores the session. The response already carries the roles
 * and effective permissions, so no `/me` round trip is needed.
 * Rejects with an `ApiError` (401 bad credentials, 400, 429 rate limited).
 */
export async function login(credentials: LoginCredentials): Promise<AuthSession> {
  const { data } = await api.post<ApiResponse<AuthSession>>(AUTH_ENDPOINTS.login, credentials);
  startSession(data.data.user, data.data.token);
  return data.data;
}

/**
 * Creates the account and stores its session. The new user already has the
 * server's default role (`user`). Rejects with an `ApiError` (422 with field
 * errors, 429 rate limited).
 */
export async function register(credentials: RegisterCredentials): Promise<AuthSession> {
  const { data } = await api.post<ApiResponse<AuthSession>>(AUTH_ENDPOINTS.register, credentials);
  startSession(data.data.user, data.data.token);
  return data.data;
}

/**
 * Reloads the signed-in user (roles and permissions may have changed on the
 * server) and updates the store. A 401 ends the session.
 */
export async function fetchMe(): Promise<User> {
  const { data } = await api.get<ApiResponse<{ user: User }>>(AUTH_ENDPOINTS.me);
  if (useAuthStore.getState().isAuthenticated) {
    useAuthStore.getState().setUser(data.data.user);
  }
  return data.data.user;
}

/**
 * Signs out: asks the server to revoke the token (on every device of the
 * user, closing their sockets too), then clears the session locally whatever
 * the server answered.
 */
export async function logout(): Promise<void> {
  // The server closes the user's sockets while it handles the request; close
  // ours first, so that close is not taken for a revoked session.
  PhoenixSocket.disconnect();
  await whileSigningOut(async () => {
    try {
      if (useAuthStore.getState().token) {
        await api.post(AUTH_ENDPOINTS.logout);
      }
    } catch (error) {
      // A 401 means the token was already dead; anything else (network) must
      // not keep the user signed in on this device.
      debugLog("logout request failed:", error);
    }
  });
  endSession("logout");
}

/**
 * Changes the signed-in user's password. The server revokes every token of
 * the user (this one too) and returns a new session, which replaces the
 * stored one; the socket reconnects with the new token. Rejects with an
 * `ApiError` (422 `current_password` / `password` field errors, 429).
 */
export async function changePassword(params: ChangePasswordParams): Promise<AuthSession> {
  return whileRotatingToken(async () => {
    const { data } = await api.put<ApiResponse<AuthSession>>(AUTH_ENDPOINTS.password, params);
    // Reopens the socket (if one was open) with the new token.
    startSession(data.data.user, data.data.token);
    return data.data;
  });
}

// --- Socket drops -----------------------------------------------------------
//
// The server closes a user's sockets when the token stops being valid
// (logout elsewhere, password change, account deleted). The socket alone
// cannot tell that apart from a network blip or a server restart, so a drop
// triggers one `GET /api/me`: a 401 there ends the session through the axios
// interceptor; anything else leaves the socket reconnecting on its own.

const VERIFY_INTERVAL_MS = 5000;
let verifying = false;
let lastVerification = 0;

async function verifySessionAfterDrop(): Promise<void> {
  const now = Date.now();
  if (verifying || now - lastVerification < VERIFY_INTERVAL_MS) return;
  if (!useAuthStore.getState().isAuthenticated || isRotatingToken()) return;

  verifying = true;
  lastVerification = now;
  try {
    await fetchMe();
  } catch (error) {
    if (!isApiError(error) || error.status !== 401) {
      debugLog("socket dropped; session check inconclusive:", error);
    }
  } finally {
    verifying = false;
  }
}

PhoenixSocket.onDrop(() => {
  void verifySessionAfterDrop();
});
