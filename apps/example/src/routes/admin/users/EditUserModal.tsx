import { useState, type SubmitEvent } from "react";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { toast } from "react-hot-toast";
import { describeError, fetchMe, useAuthStore } from "@rephi/shared-components";
import { ErrorAlert, FieldError, Modal } from "~/components/commons";
import { adminKeys, usersApi } from "~/modules/api/admin";
import type { UserWithGrants } from "~/types/admin.types";

interface EditUserModalProps {
  user: UserWithGrants;
  onClose: () => void;
}

/**
 * Changes a user's email (`users:edit`). Passwords cannot be set for other
 * users: everyone changes their own from the profile page.
 */
export default function EditUserModal({ user, onClose }: EditUserModalProps) {
  const queryClient = useQueryClient();
  const currentUserId = useAuthStore((state) => state.user?.id);
  const [email, setEmail] = useState(user.email);

  const save = useMutation({
    mutationFn: () => usersApi.updateEmail(user.id, email.trim()),
    onSuccess: (updated) => {
      toast.success(`Email changed to ${updated.email}`);
      queryClient.invalidateQueries({ queryKey: adminKeys.users });
      if (updated.id === currentUserId) fetchMe().catch(() => {});
      onClose();
    },
  });

  const error = save.error ? describeError(save.error) : null;
  const hasFieldErrors = !!error && Object.keys(error.fieldErrors).length > 0;

  const handleSubmit = (event: SubmitEvent<HTMLFormElement>) => {
    event.preventDefault();
    save.mutate();
  };

  return (
    <Modal isOpen onClose={onClose} title={`Edit ${user.email}`}>
      <form onSubmit={handleSubmit} noValidate>
        <ErrorAlert message={error && !hasFieldErrors ? error.message : null} />
        <div className="mb-4">
          <label htmlFor="user-email" className="block text-sm font-medium mb-2 text-gray-500">
            Email
          </label>
          <input
            id="user-email"
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            className="w-full border rounded px-3 py-2 text-gray-900"
            required
          />
          <FieldError errors={error?.fieldErrors ?? {}} field="email" />
        </div>
        <div className="flex justify-end gap-2">
          <button type="button" onClick={onClose} className="px-4 py-2 border rounded hover:bg-gray-50 text-gray-700">
            Cancel
          </button>
          <button
            type="submit"
            disabled={save.isPending}
            className="bg-blue-600 text-white px-4 py-2 rounded hover:bg-blue-700 disabled:opacity-50"
          >
            {save.isPending ? "Saving..." : "Save"}
          </button>
        </div>
      </form>
    </Modal>
  );
}
