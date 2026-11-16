import { zodResolver } from "@hookform/resolvers/zod";
import { useState } from "react";
import { useForm } from "react-hook-form";
import IslandProviders from "~/components/react/IslandProviders";
import { useRegister } from "~/hooks/useAuth";
import { applyServerErrors } from "~/lib/forms";
import { registrationSchema } from "~/lib/passwords";
import type { RegisterCredentials } from "~/lib/rephi";

type RegisterFormData = RegisterCredentials;

const inputClassName =
  "mt-1 appearance-none relative block w-full px-3 py-2 border border-gray-300 placeholder-gray-500 text-gray-900 rounded-md focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 focus:z-10 sm:text-sm";

function RegisterFormFields() {
  const registerMutation = useRegister();
  const [serverError, setServerError] = useState<string | null>(null);

  const {
    register,
    handleSubmit,
    setError,
    formState: { errors },
  } = useForm<RegisterFormData>({
    resolver: zodResolver(registrationSchema),
  });

  const onSubmit = (data: RegisterFormData) => {
    setServerError(null);
    registerMutation.mutate(data, {
      onError: (error) =>
        setServerError(
          applyServerErrors(error, setError, ["email", "password", "password_confirmation"])
        ),
    });
  };

  return (
    <form className="mt-8 space-y-6" onSubmit={handleSubmit(onSubmit)} noValidate>
      {serverError && (
        <div className="rounded-md bg-red-50 p-4" role="alert">
          <div className="text-sm text-red-800">{serverError}</div>
        </div>
      )}

      <div className="space-y-4">
        <div>
          <label
            htmlFor="email"
            className="block text-sm font-medium text-gray-700"
          >
            Email address
          </label>
          <input
            {...register("email")}
            id="email"
            type="email"
            autoComplete="email"
            className={inputClassName}
            placeholder="Email address"
          />
          {errors.email && (
            <p className="mt-1 text-sm text-red-600">
              {errors.email.message}
            </p>
          )}
        </div>

        <div>
          <label
            htmlFor="password"
            className="block text-sm font-medium text-gray-700"
          >
            Password
          </label>
          <input
            {...register("password")}
            id="password"
            type="password"
            autoComplete="new-password"
            className={inputClassName}
            placeholder="Password"
          />
          {errors.password && (
            <p className="mt-1 text-sm text-red-600">
              {errors.password.message}
            </p>
          )}
        </div>

        <div>
          <label
            htmlFor="password_confirmation"
            className="block text-sm font-medium text-gray-700"
          >
            Confirm Password
          </label>
          <input
            {...register("password_confirmation")}
            id="password_confirmation"
            type="password"
            autoComplete="new-password"
            className={inputClassName}
            placeholder="Confirm Password"
          />
          {errors.password_confirmation && (
            <p className="mt-1 text-sm text-red-600">
              {errors.password_confirmation.message}
            </p>
          )}
        </div>
      </div>

      <div>
        <button
          type="submit"
          disabled={registerMutation.isPending}
          className="group relative w-full flex justify-center py-2 px-4 border border-transparent text-sm font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 disabled:opacity-50 disabled:cursor-not-allowed"
        >
          {registerMutation.isPending
            ? "Creating account..."
            : "Create account"}
        </button>
      </div>
    </form>
  );
}

export default function RegisterForm() {
  return (
    <IslandProviders>
      <RegisterFormFields />
    </IslandProviders>
  );
}
