import { zodResolver } from "@hookform/resolvers/zod";
import { useSyncExternalStore } from "react";
import { useForm } from "react-hook-form";
import { z } from "zod";
import IslandProviders from "~/components/react/IslandProviders";
import { useLogin } from "~/hooks/useAuth";
import { getRedirectPath } from "~/lib/rephi";
import type { LoginCredentials } from "~/lib/rephi";

const loginSchema = z.object({
  email: z.email("Invalid email address"),
  password: z.string().min(6, "Password must be at least 6 characters"),
});

// The "redirect back" target lives in sessionStorage, which only exists in the
// browser. Reading it through an external store with a server snapshot keeps
// the prerendered HTML and the first client render identical.
const subscribeToNothing = () => () => {};
const hasRedirectTarget = () => getRedirectPath() !== null;
const noRedirectTarget = () => false;

function LoginFormFields() {
  const loginMutation = useLogin();
  const redirected = useSyncExternalStore(
    subscribeToNothing,
    hasRedirectTarget,
    noRedirectTarget
  );

  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm<LoginCredentials>({
    resolver: zodResolver(loginSchema),
  });

  const onSubmit = (data: LoginCredentials) => {
    loginMutation.mutate(data);
  };

  return (
    <form className="mt-8 space-y-6" onSubmit={handleSubmit(onSubmit)} noValidate>
      {redirected && (
        <div className="rounded-md bg-blue-50 p-4">
          <div className="text-sm text-blue-800">
            You need to login to access that page.
          </div>
        </div>
      )}

      {loginMutation.isError && (
        <div className="rounded-md bg-red-50 p-4" role="alert">
          <div className="text-sm text-red-800">
            {loginMutation.error?.message ||
              "An error occurred during login"}
          </div>
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
  );
}

export default function LoginForm() {
  return (
    <IslandProviders>
      <LoginFormFields />
    </IslandProviders>
  );
}
