import { create } from "zustand";
import { createJSONStorage, persist } from "zustand/middleware";
import type { SessionEndReason, User } from "../types";
import { getStorage } from "../utils/storage";

export const AUTH_STORAGE_KEY = "auth-storage";

interface AuthState {
  user: User | null;
  token: string | null;
  isAuthenticated: boolean;
  sessionEndReason: SessionEndReason | null;
  setSession: (user: User, token: string) => void;
  setUser: (user: User) => void;
  clear: (reason?: SessionEndReason) => void;
}

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
