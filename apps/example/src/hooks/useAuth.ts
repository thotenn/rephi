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

// No navigation here: the route guards follow the auth store, so there is a single place for each redirect.

export function useLogin() {
  const queryClient = useQueryClient();

  return useMutation<AuthSession, Error, LoginCredentials>({
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

export function useLogout() {
  return useMutation<void, Error, void>({ mutationFn: logout });
}

export function useChangePassword() {
  return useMutation<AuthSession, Error, ChangePasswordParams>({ mutationFn: changePassword });
}
