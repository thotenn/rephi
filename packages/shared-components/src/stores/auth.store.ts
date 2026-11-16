import { create } from "zustand";
import { createJSONStorage, persist } from "zustand/middleware";
import type { SessionEndReason, User } from "../types";
import { getStorage } from "../utils/storage";

/** localStorage key of the persisted session. */
export const AUTH_STORAGE_KEY = "auth-storage";

interface AuthState {
  user: User | null;
  token: string | null;
  isAuthenticated: boolean;
  /**
   * Why the last session ended, until a new one starts. Not persisted: it lets
   * the login page tell "you signed out" from "your session expired".
   */
  sessionEndReason: SessionEndReason | null;
  /** Starts a session (login, register, password change). */
  setSession: (user: User, token: string) => void;
  /** Replaces the user of the current session (e.g. after `GET /api/me`). */
  setUser: (user: User) => void;
  /**
   * Forgets the session locally. Prefer `logout()` (tells the server) or
   * `endSession()` (also closes the socket and notifies listeners).
   */
  clear: (reason?: SessionEndReason) => void;
}

// Without a browser (SSR, prerendering, tests in Node) the session is kept in
// memory only.
const memoryStorage: Storage = (() => {
  const data = new Map<string, string>();
  return {
    get length() {
      return data.size;
    },
    clear: () => data.clear(),
    getItem: (key) => data.get(key) ?? null,
    key: (index) => Array.from(data.keys())[index] ?? null,
    removeItem: (key) => {
      data.delete(key);
    },
    setItem: (key, value) => {
      data.set(key, value);
    },
  };
})();

export const useAuthStore = create<AuthState>()(
  persist(
    (set) => ({
      user: null,
      token: null,
      isAuthenticated: false,
      sessionEndReason: null,
      setSession: (user, token) =>
        set({ user, token, isAuthenticated: true, sessionEndReason: null }),
      setUser: (user) => set({ user }),
      clear: (reason = "logout") =>
        set({ user: null, token: null, isAuthenticated: false, sessionEndReason: reason }),
    }),
    {
      name: AUTH_STORAGE_KEY,
      storage: createJSONStorage(() => getStorage("local") ?? memoryStorage),
      partialize: ({ user, token, isAuthenticated }) => ({ user, token, isAuthenticated }),
    }
  )
);

// Keeps every tab on the same session: signing out (or in) in one tab is
// picked up by the others through the `storage` event.
if (typeof window !== "undefined") {
  window.addEventListener("storage", (event) => {
    if (event.key !== AUTH_STORAGE_KEY && event.key !== null) return;
    const wasAuthenticated = useAuthStore.getState().isAuthenticated;
    void Promise.resolve(useAuthStore.persist.rehydrate()).then(() => {
      const state = useAuthStore.getState();
      if (wasAuthenticated && !state.isAuthenticated) {
        useAuthStore.setState({ sessionEndReason: "logout" });
      }
    });
  });
}
