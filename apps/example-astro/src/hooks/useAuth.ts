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

function leaveGuestPage(): void {
  const redirectPath = getRedirectPath();
  clearRedirectPath();
  if (isInternalPath(redirectPath)) {
    goToPath(redirectPath, { replace: true });
  } else {
    go(ROUTES.home, { replace: true });
  }
}

export function useLogin() {
  const queryClient = useQueryClient();

  return useMutation<AuthSession, Error, LoginCredentials>({
    onMutate: () => queryClient.clear(),
    mutationFn: login,
    onSuccess: leaveGuestPage,
  });
}

export function useRegister() {
  const queryClient = useQueryClient();

  return useMutation<AuthSession, Error, RegisterCredentials>({
    onMutate: () => queryClient.clear(),
    mutationFn: register,
    onSuccess: leaveGuestPage,
  });
}

export function useChangePassword() {
  return useMutation<AuthSession, Error, ChangePasswordParams>({ mutationFn: changePassword });
}

// No navigation here: RouteGuard and AppRuntime react to the store.
export function signOut(): Promise<void> {
  return logout();
}
