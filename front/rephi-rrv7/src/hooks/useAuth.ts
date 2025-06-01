import { useMutation } from "@tanstack/react-query";
import { useNavigate } from "react-router-dom";
import api from "~/modules/api/api";
import PhoenixSocket from "~/modules/api/socket";
import { useAuthStore } from "~/stores/auth.store";
import type {
  AuthResponse,
  LoginCredentials,
  RegisterCredentials,
} from "~/types/auth.types";
import type { ApiError } from "~/types/api.types";
import { apisUrl, urls } from "~/env";

export function useLogin() {
  const navigate = useNavigate();
  const setAuth = useAuthStore((state) => state.setAuth);

  return useMutation<AuthResponse, ApiError, LoginCredentials>({
    mutationFn: async (credentials) => {
      const { data } = await api.post(apisUrl.auth.login, credentials);
      return data;
    },
    onSuccess: (data) => {
      setAuth(data.user, data.token);
      navigate(urls.home);
    },
  });
}

export function useRegister() {
  const navigate = useNavigate();
  const setAuth = useAuthStore((state) => state.setAuth);

  return useMutation<AuthResponse, ApiError, RegisterCredentials>({
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
