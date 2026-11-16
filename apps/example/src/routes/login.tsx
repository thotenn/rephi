import { useState } from "react";
import { Link, useLocation } from "react-router";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import type { LoginCredentials } from "@rephi/shared-components";
import { ROUTE_PATHS } from "~/config/routes";
import { useLogin } from "~/hooks/useAuth";
import { applyServerErrors } from "~/utils/forms";
import type { LoginLocationState } from "~/utils/redirect";

// No minimum length here: accounts created under older, shorter password
// rules can still sign in. The rules apply when a password is set.
const loginSchema = z.object({
  email: z.email("Invalid email address"),
  password: z.string().min(1, "Password is required"),
});

const sessionNotices = {
  logout: "You have been signed out.",
  unauthorized: "Your session has ended. Please sign in again.",
} as const;

export default function Login() {
  const location = useLocation();
  const state = (location.state ?? {}) as LoginLocationState;
  const notice = state.sessionEnded
    ? sessionNotices[state.sessionEnded]
    : state.from
      ? "You need to login to access that page."
      : null;
  const loginMutation = useLogin();
  const [serverError, setServerError] = useState<string | null>(null);

  const {
    register,
    handleSubmit,
    setError,
    formState: { errors },
  } = useForm<LoginCredentials>({
    resolver: zodResolver(loginSchema),
  });

  const onSubmit = (data: LoginCredentials) => {
    setServerError(null);
    loginMutation.mutate(data, {
      onError: (error) => setServerError(applyServerErrors(error, setError, ["email", "password"])),
    });
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-50 py-12 px-4 sm:px-6 lg:px-8">
      <div className="max-w-md w-full space-y-8">
        <div>
          <h2 className="mt-6 text-center text-3xl font-extrabold text-gray-900">
            Sign in to your account
          </h2>
          <p className="mt-2 text-center text-sm text-gray-600">
            Or{" "}
            <Link
              to={ROUTE_PATHS.auth.register}
              className="font-medium text-indigo-600 hover:text-indigo-500"
            >
              create a new account
            </Link>
          </p>
        </div>

        <form className="mt-8 space-y-6" onSubmit={handleSubmit(onSubmit)} noValidate>
          {notice && !serverError && (
            <div className="rounded-md bg-blue-50 p-4">
              <div className="text-sm text-blue-800">{notice}</div>
            </div>
          )}

          {serverError && (
            <div className="rounded-md bg-red-50 p-4" role="alert">
              <div className="text-sm text-red-800">{serverError}</div>
            </div>
          )}

          <div className="rounded-md shadow-sm -space-y-px">
            <div>
              <label htmlFor="email" className="sr-only">
                Email address
              </label>
              <input
                {...register("email")}
                id="email"
                type="email"
                autoComplete="email"
                className="appearance-none rounded-none relative block w-full px-3 py-2 border border-gray-300 placeholder-gray-500 text-gray-900 rounded-t-md focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 focus:z-10 sm:text-sm"
                placeholder="Email address"
              />
              {errors.email && (
                <p className="mt-1 text-sm text-red-600">
                  {errors.email.message}
                </p>
              )}
            </div>
            <div>
              <label htmlFor="password" className="sr-only">
                Password
              </label>
              <input
                {...register("password")}
                id="password"
                type="password"
                autoComplete="current-password"
                className="appearance-none rounded-none relative block w-full px-3 py-2 border border-gray-300 placeholder-gray-500 text-gray-900 rounded-b-md focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 focus:z-10 sm:text-sm"
                placeholder="Password"
              />
              {errors.password && (
                <p className="mt-1 text-sm text-red-600">
                  {errors.password.message}
                </p>
              )}
            </div>
          </div>

          <div>
            <button
              type="submit"
              disabled={loginMutation.isPending}
              className="group relative w-full flex justify-center py-2 px-4 border border-transparent text-sm font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {loginMutation.isPending ? "Signing in..." : "Sign in"}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
