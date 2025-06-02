import { useMutation } from "@tanstack/react-query";
import { useNavigate } from "react-router-dom";
import api from "~/modules/api/api";
import PhoenixSocket from "~/modules/api/socket";
import { useAuthStore } from "~/stores/auth.store";
import { getRedirectPath, clearRedirectPath } from "~/components/bedrock/routes/routes_utils";
import type {
  AuthResponse,
  LoginCredentials,
  RegisterCredentials,
} from "~/types/auth.types";
import { apisUrl, urls } from "~/env";

export function useLogin() {
  const navigate = useNavigate();
  const setAuth = useAuthStore((state) => state.setAuth);

  return useMutation<AuthResponse, Error, LoginCredentials>({
    mutationFn: async (credentials) => {
      const { data } = await api.post(apisUrl.auth.login, credentials);
      return data;
    },
    onSuccess: (data) => {
      // Set auth first
      setAuth(data.user, data.token);
      
      // Get redirect path from sessionStorage
      const redirectPath = getRedirectPath();
      if (process.env.NODE_ENV === "development") {
        console.log("Login successful. Redirect path from storage:", redirectPath);
      }
      
      // Navigate after a small delay to ensure state is updated
      setTimeout(() => {
        const targetPath = redirectPath || urls.home;
        if (process.env.NODE_ENV === "development") {
          console.log("Navigating to:", targetPath);
        }
        navigate(targetPath, { replace: true });
        // Clear the redirect path after successful navigation
        clearRedirectPath();
      }, 100);
    },
  });
}

export function useRegister() {
  const navigate = useNavigate();
  const setAuth = useAuthStore((state) => state.setAuth);

  return useMutation<AuthResponse, Error, RegisterCredentials>({
    mutationFn: async (credentials) => {
      const { data } = await api.post(apisUrl.auth.register, credentials);
      return data;
    },
    onSuccess: (data) => {
      setAuth(data.user, data.token);
      navigate(urls.home);
    },
  });
}

export function useLogout() {
  const navigate = useNavigate();
  const logout = useAuthStore((state) => state.logout);

  return () => {
    logout();
    navigate(urls.auth.login);
    PhoenixSocket.disconnect();
  };
}
