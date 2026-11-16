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

export const AUTH_ENDPOINTS = {
  login: "/users/login",
  register: "/users/register",
  logout: "/users/logout",
  me: "/me",
  password: "/me/password",
} as const;

export async function login(credentials: LoginCredentials): Promise<AuthSession> {
  const { data } = await api.post<ApiResponse<AuthSession>>(AUTH_ENDPOINTS.login, credentials);
  startSession(data.data.user, data.data.token);
  return data.data;
}

export async function register(credentials: RegisterCredentials): Promise<AuthSession> {
  const { data } = await api.post<ApiResponse<AuthSession>>(AUTH_ENDPOINTS.register, credentials);
  startSession(data.data.user, data.data.token);
  return data.data;
}

export async function fetchMe(): Promise<User> {
  const { data } = await api.get<ApiResponse<{ user: User }>>(AUTH_ENDPOINTS.me);
  if (useAuthStore.getState().isAuthenticated) {
    useAuthStore.getState().setUser(data.data.user);
  }
  return data.data.user;
}

export async function logout(): Promise<void> {
  // Close ours first, so the server closing it is not taken for a revoked session.
  PhoenixSocket.disconnect();
  await whileSigningOut(async () => {
    try {
      if (useAuthStore.getState().token) {
        await api.post(AUTH_ENDPOINTS.logout);
      }
    } catch (error) {
      debugLog("logout request failed:", error);
    }
  });
  endSession("logout");
}

export async function changePassword(params: ChangePasswordParams): Promise<AuthSession> {
  return whileRotatingToken(async () => {
    const { data } = await api.put<ApiResponse<AuthSession>>(AUTH_ENDPOINTS.password, params);
    startSession(data.data.user, data.data.token);
    return data.data;
  });
}

// A socket drop can be a revoked token or a network blip: one GET /api/me tells them apart.
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
