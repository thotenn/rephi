import { debugLog } from "./config";
import PhoenixSocket from "./controllers/api/socket";
import { useAuthStore } from "./stores/auth.store";
import type { SessionEndReason, User } from "./types";

type SessionEndListener = (reason: SessionEndReason) => void;

const listeners = new Set<SessionEndListener>();

/** Runs after the store is cleared; navigate on `isAuthenticated`, which also covers other tabs. */
export function onSessionEnd(listener: SessionEndListener): () => void {
  listeners.add(listener);
  return () => {
    listeners.delete(listener);
  };
}

export function startSession(user: User, token: string): void {
  const hadSocket = PhoenixSocket.getSocket() !== null;
  useAuthStore.getState().setSession(user, token);
  if (hadSocket) PhoenixSocket.reconnect();
}

export function endSession(reason: SessionEndReason): void {
  if (!useAuthStore.getState().isAuthenticated) return;
  debugLog("session ended:", reason);
  useAuthStore.getState().clear(reason);
  PhoenixSocket.disconnect();
  listeners.forEach((listener) => listener(reason));
}

// During a password change the server drops the socket and the old token on purpose.
let rotating = 0;

export async function whileRotatingToken<T>(fn: () => Promise<T>): Promise<T> {
  rotating += 1;
  try {
    return await fn();
  } finally {
    rotating -= 1;
  }
}

export function isRotatingToken(): boolean {
  return rotating > 0;
}

// During logout() a 401 on an in-flight request is expected, not an expired session.
let signingOut = false;

export async function whileSigningOut<T>(fn: () => Promise<T>): Promise<T> {
  signingOut = true;
  try {
    return await fn();
  } finally {
    signingOut = false;
  }
}

export function isSigningOut(): boolean {
  return signingOut;
}
