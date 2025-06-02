import axios from "axios";
import { useAuthStore } from "~/stores/auth.store";
import { API_URL } from "~/env";
import type { ApiError } from "~/types/api.types";

const api = axios.create({
  baseURL: API_URL,
  withCredentials: true,
});

api.interceptors.request.use((config) => {
  const token = useAuthStore.getState().token;
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

// Response interceptor for error handling
api.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response) {
      // Normalize error format
      const apiError: ApiError = error.response.data || {};
      
      // Extract meaningful error message
      let errorMessage = "An error occurred";
      
      if (apiError.error) {
        errorMessage = apiError.error;
      } else if (apiError.message) {
        errorMessage = apiError.message;
      } else if (apiError.errors) {
        // Convert validation errors to a single message
        const firstError = Object.values(apiError.errors)[0];
        if (Array.isArray(firstError) && firstError.length > 0) {
          errorMessage = firstError[0];
        }
      }
      
      // Create normalized error
      const normalizedError = new Error(errorMessage);
      Object.assign(normalizedError, {
        response: error.response,
        apiError: apiError
      });
      
      return Promise.reject(normalizedError);
    }
    
    return Promise.reject(error);
  }
);

export default api;
