import { useMutation, useQueryClient } from "@tanstack/react-query";
import { go, goToPath } from "~/lib/navigation";
import {
  api,
  clearRedirectPath,
  env,
  getRedirectPath,
  useAuthStore,
} from "~/lib/rephi";
import type {
  AuthResponse,
  LoginCredentials,
  RegisterCredentials,
} from "~/lib/rephi";
import { isInternalPath, ROUTES } from "~/lib/routes";

/**
 * Stores the session returned by login / register, then completes it with the
 * roles and permissions from `/me` (the auth endpoints only return id + email).
 */
async function startSession({ user, token }: AuthResponse): Promise<void> {
  const { setAuth } = useAuthStore.getState();

  // Set auth first: the axios interceptor reads the token from the store.
  setAuth(user, token);

  try {
    const profile = await api.get(env.API.auth.me);
    if (profile.data?.user) {
      setAuth(profile.data.user, token);
    }
  } catch (error) {
    console.warn("Failed to fetch user profile:", error);
  }
}

export function useLogin() {
  const queryClient = useQueryClient();

  return useMutation<AuthResponse, Error, LoginCredentials>({
    mutationFn: async (credentials) => {
      const { data } = await api.post(env.API.auth.login, credentials);
      return data;
    },
    onSuccess: async (data) => {
      await startSession(data);

      // Drop anything cached for a previous session.
      queryClient.clear();

      // Go back to the protected page that sent the visitor here, if any.
      const redirectPath = getRedirectPath();
      clearRedirectPath();

      if (isInternalPath(redirectPath)) {
        goToPath(redirectPath, { replace: true });
      } else {
        go(ROUTES.home, { replace: true });
      }
    },
  });
}

export function useRegister() {
  const queryClient = useQueryClient();

  return useMutation<AuthResponse, Error, RegisterCredentials>({
    mutationFn: async (credentials) => {
      const { data } = await api.post(env.API.auth.register, credentials);
      return data;
    },
    onSuccess: async (data) => {
      await startSession(data);
      queryClient.clear();
      clearRedirectPath();
      go(ROUTES.home, { replace: true });
    },
  });
}

/**
 * Ends the session. Navigation is not done here: `RouteGuard` reacts to the
 * store and sends the visitor to the login page, and `AppRuntime` closes the
 * socket, so every consequence of losing the session lives in one place.
 */
export function logout(): void {
  useAuthStore.getState().logout();
}
