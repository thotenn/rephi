import { create } from "zustand";
import { persist } from "zustand/middleware";
import { storeNames } from "~/env";
import { User } from "~/types/auth.types";

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
