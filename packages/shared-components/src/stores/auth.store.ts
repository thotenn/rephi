import { create } from "zustand";
import { persist } from "zustand/middleware";
import { env } from "@/env";
import type { User } from "@/types";

const storeNames = env.STORES.exampleStore;

interface AuthState {
  user: User | null;
  token: string | null;
  isAuthenticated: boolean;
  setAuth: (user: User, token: string) => void;
  logout: () => void;
}

export const useAuthStore = create<AuthState>()(
  persist(
    (set) => ({
      user: null,
      token: null,
      isAuthenticated: false,
      setAuth: (user, token) => {
        set({ user, token, isAuthenticated: true });
        // Also set token in localStorage for socket connection
        localStorage.setItem(storeNames.authToken, token);
      },
      logout: () => {
        set({ user: null, token: null, isAuthenticated: false });
        localStorage.removeItem(storeNames.authToken);
      },
    }),
    {
      name: "auth-storage",
    }
  )
);
