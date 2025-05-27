import { useMutation } from '@tanstack/react-query';
import { useNavigate } from '@remix-run/react';
import api from '~/modules/api/api';
import { useAuthStore } from '~/stores/auth.store';
import type { AuthResponse, LoginCredentials, RegisterCredentials } from '~/types/auth.types';
import type { ApiError } from '~/types/api.types';

export function useLogin() {
  const navigate = useNavigate();
  const setAuth = useAuthStore((state) => state.setAuth);

  return useMutation<AuthResponse, ApiError, LoginCredentials>({
    mutationFn: async (credentials) => {
      const { data } = await api.post('/login', credentials);
      return data;
    },
    onSuccess: (data) => {
      setAuth(data.user, data.token);
      navigate('/dashboard');
    },
  });
}

export function useRegister() {
  const navigate = useNavigate();
  const setAuth = useAuthStore((state) => state.setAuth);

  return useMutation<AuthResponse, ApiError, RegisterCredentials>({
    mutationFn: async (credentials) => {
      const { data } = await api.post('/register', { user: credentials });
      return data;
    },
    onSuccess: (data) => {
      setAuth(data.user, data.token);
      navigate('/dashboard');
    },
  });
}

export function useLogout() {
  const navigate = useNavigate();
  const logout = useAuthStore((state) => state.logout);

  return () => {
    logout();
    navigate('/login');
  };
}