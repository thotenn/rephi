import { useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { toast } from "react-hot-toast";
import { useAuthStore, type ChangePasswordParams } from "~/lib/rephi";
import IslandProviders from "~/components/react/IslandProviders";
import { useChangePassword } from "~/hooks/useAuth";
import { applyServerErrors } from "~/lib/forms";
import { changePasswordSchema } from "~/lib/passwords";

const FIELDS = ["current_password", "password", "password_confirmation"] as const;

const inputClassName =
  "mt-1 appearance-none relative block w-full px-3 py-2 border border-gray-300 placeholder-gray-500 text-gray-900 rounded-md focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm";

const labels: Record<(typeof FIELDS)[number], string> = {
  current_password: "Current password",
  password: "New password",
  password_confirmation: "Confirm new password",
};

const autoComplete: Record<(typeof FIELDS)[number], string> = {
  current_password: "current-password",
  password: "new-password",
  password_confirmation: "new-password",
};

/**
 * `PUT /api/me/password`. The server signs out every other device of the user
 * and returns a new session, which the library stores (the socket reconnects
 * with the new token), so the user stays signed in here.
 */
function ChangePasswordFields() {
  const changePassword = useChangePassword();
  const mustChangePassword = useAuthStore((state) => !!state.user?.must_change_password);
  const [serverError, setServerError] = useState<string | null>(null);

  const {
    register,
    handleSubmit,
    reset,
    setError,
    formState: { errors },
  } = useForm<ChangePasswordParams>({
    resolver: zodResolver(changePasswordSchema),
  });

  const onSubmit = (data: ChangePasswordParams) => {
    setServerError(null);
    changePassword.mutate(data, {
      onSuccess: () => {
        reset();
        toast.success("Password changed. Other devices have been signed out.");
      },
      onError: (error) => setServerError(applyServerErrors(error, setError, FIELDS)),
    });
  };

  return (
    <div className="mt-8 bg-white overflow-hidden shadow rounded-lg">
      <div className="px-4 py-5 sm:p-6">
        <h2 className="text-lg font-medium text-gray-900 mb-4">Change Password</h2>
        {mustChangePassword && (
          <div className="rounded-md bg-yellow-50 border border-yellow-300 p-4 mb-4 max-w-md" role="alert" data-testid="must-change-password">
            <p className="text-sm text-yellow-900">
              An administrator reset your password. Enter the temporary password you were given as
              the current password and choose a new one to continue.
            </p>
          </div>
        )}
        <form className="space-y-4 max-w-md" onSubmit={handleSubmit(onSubmit)} noValidate>
          {serverError && (
            <div className="rounded-md bg-red-50 p-4" role="alert">
              <div className="text-sm text-red-800">{serverError}</div>
            </div>
          )}
          {FIELDS.map((field) => (
            <div key={field}>
              <label htmlFor={`cp-${field}`} className="block text-sm font-medium text-gray-700">
                {labels[field]}
              </label>
              <input
                {...register(field)}
                id={`cp-${field}`}
                type="password"
                autoComplete={autoComplete[field]}
                className={inputClassName}
              />
              {errors[field] && (
                <p className="mt-1 text-sm text-red-600">{errors[field]?.message}</p>
              )}
            </div>
          ))}
          <button
            type="submit"
            disabled={changePassword.isPending}
            className="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {changePassword.isPending ? "Changing..." : "Change password"}
          </button>
        </form>
      </div>
    </div>
  );
}

export default function ChangePasswordForm() {
  return (
    <IslandProviders>
      <ChangePasswordFields />
    </IslandProviders>
  );
}
