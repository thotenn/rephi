import { debugLog } from "./config";
import PhoenixSocket from "./controllers/api/socket";
import { useAuthStore } from "./stores/auth.store";
import type { SessionEndReason, User } from "./types";

type SessionEndListener = (reason: SessionEndReason) => void;

const listeners = new Set<SessionEndListener>();

/**
 * Runs `listener` every time the session ends: on `logout()` and when the
 * server rejects the token (any 401 on an authenticated request, or the socket
 * being closed by the server for a token that no longer works). By then the
 * store is already cleared and the socket closed; apps use it to drop cached
 * data and tell the user. Navigation to the login page should follow the
 * store (`isAuthenticated`), which also covers sign-outs in other tabs.
 */
export function onSessionEnd(listener: SessionEndListener): () => void {
  listeners.add(listener);
  return () => {
    listeners.delete(listener);
  };
}

/** Starts a session: stores user and token, and (re)opens the socket if one was open. */
export function startSession(user: User, token: string): void {
  const hadSocket = PhoenixSocket.getSocket() !== null;
  useAuthStore.getState().setSession(user, token);
  if (hadSocket) PhoenixSocket.reconnect();
}

/**
 * Ends the session locally: clears the store, closes the socket and notifies
 * `onSessionEnd` listeners. Does not call the server (see `logout()`).
 * A no-op when there is no session.
 */
export function endSession(reason: SessionEndReason): void {
  if (!useAuthStore.getState().isAuthenticated) return;
  debugLog("session ended:", reason);
  useAuthStore.getState().clear(reason);
  PhoenixSocket.disconnect();
  listeners.forEach((listener) => listener(reason));
}

// While the token is being replaced (password change), the server closes the
// socket on purpose and the old token stops working; neither means the
// session ended.
let rotating = 0;

/** Internal: runs `fn` while socket drops are not treated as a lost session. */
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

// While `logout()` runs, the token is being revoked on purpose: a 401 on a
// request still in flight is expected and must not report an expired session.
let signingOut = false;

/** Internal: runs `fn` while 401s are left for `logout()` to handle. */
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
