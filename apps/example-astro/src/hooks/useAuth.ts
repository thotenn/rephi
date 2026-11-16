import { useMutation, useQueryClient } from "@tanstack/react-query";
import { go, goToPath } from "~/lib/navigation";
import {
  changePassword,
  clearRedirectPath,
  getRedirectPath,
  login,
  logout,
  register,
} from "~/lib/rephi";
import type {
  AuthSession,
  ChangePasswordParams,
  LoginCredentials,
  RegisterCredentials,
} from "~/lib/rephi";
import { isInternalPath, ROUTES } from "~/lib/routes";

/** After signing in: back to the protected page that sent the visitor here, or home. */
function leaveGuestPage(): void {
  const redirectPath = getRedirectPath();
  clearRedirectPath();
  if (isInternalPath(redirectPath)) {
    goToPath(redirectPath, { replace: true });
  } else {
    go(ROUTES.home, { replace: true });
  }
}

/**
 * Signs in. The response carries the roles and permissions, so the session is
 * complete at once; the form then navigates exactly once.
 */
export function useLogin() {
  const queryClient = useQueryClient();

  return useMutation<AuthSession, Error, LoginCredentials>({
    // Drop anything cached for a previous session before the new one starts.
    onMutate: () => queryClient.clear(),
    mutationFn: login,
    onSuccess: leaveGuestPage,
  });
}

/** Creates the account (with the server's default role) and signs it in. */
export function useRegister() {
  const queryClient = useQueryClient();

  return useMutation<AuthSession, Error, RegisterCredentials>({
    onMutate: () => queryClient.clear(),
    mutationFn: register,
    onSuccess: leaveGuestPage,
  });
}

/** Changes the password; the new session replaces the stored one. */
export function useChangePassword() {
  return useMutation<AuthSession, Error, ChangePasswordParams>({ mutationFn: changePassword });
}

/**
 * Ends the session on the server (revokes the token on every device), then
 * locally. Navigation is not done here: `RouteGuard` reacts to the store and
 * sends the visitor to the login page, and `AppRuntime` follows the session
 * for the socket, so every consequence of losing the session lives in one place.
 */
export function signOut(): Promise<void> {
  return logout();
}
