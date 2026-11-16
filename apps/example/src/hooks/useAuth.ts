import { useMutation, useQueryClient } from "@tanstack/react-query";
import {
  changePassword,
  login,
  logout,
  register,
  type AuthSession,
  type ChangePasswordParams,
  type LoginCredentials,
  type RegisterCredentials,
} from "@rephi/shared-components";

/*
 * Navigation is not done here: the route guards follow the auth store.
 * `PublicRoute` leaves the login / register page once a session exists (to the
 * page the visitor wanted, or home) and `ProtectedRoute` sends a visitor whose
 * session ended to the login page. One place each, so no double navigation.
 */

export function useLogin() {
  const queryClient = useQueryClient();

  return useMutation<AuthSession, Error, LoginCredentials>({
    // Drop anything cached for a previous session before the new one starts.
    onMutate: () => queryClient.clear(),
    mutationFn: login,
  });
}

export function useRegister() {
  const queryClient = useQueryClient();

  return useMutation<AuthSession, Error, RegisterCredentials>({
    onMutate: () => queryClient.clear(),
    mutationFn: register,
  });
}

/** Signs out on the server (revokes the token everywhere), then locally. */
export function useLogout() {
  return useMutation<void, Error, void>({ mutationFn: logout });
}

/** Changes the password; the new session replaces the stored one. */
export function useChangePassword() {
  return useMutation<AuthSession, Error, ChangePasswordParams>({ mutationFn: changePassword });
}
