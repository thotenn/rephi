import { useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { fetchMe, getErrorMessage, useAuthStore, usePermissions } from "~/lib/rephi";
import { ErrorAlert, Modal } from "~/components/react";
import { adminKeys, rolesApi, usersApi } from "~/lib/api/admin";
import type { UserWithGrants } from "~/types/admin.types";
import { roleBadgeClass } from "~/lib/roles";

interface UserRolesModalProps {
  user: UserWithGrants;
  onClose: () => void;
}

/**
 * Assigns and removes roles of a user (`roles:assign`). The server refuses
 * (and this shows why) granting a role the signed-in user does not hold (403)
 * or removing the admin role from the last admin (409).
 */
export default function UserRolesModal({ user, onClose }: UserRolesModalProps) {
  const queryClient = useQueryClient();
  const { can } = usePermissions();
  const currentUserId = useAuthStore((state) => state.user?.id);
  const [error, setError] = useState<string | null>(null);

  const userRoles = useQuery({ queryKey: adminKeys.userRoles(user.id), queryFn: () => usersApi.roles(user.id) });
  const allRoles = useQuery({ queryKey: adminKeys.allRoles, queryFn: rolesApi.all, enabled: can("roles:view") });

  const afterChange = () => {
    setError(null);
    queryClient.invalidateQueries({ queryKey: adminKeys.users });
    if (user.id === currentUserId) fetchMe().catch(() => {});
  };

  const assign = useMutation({
    mutationFn: (roleId: number) => usersApi.assignRole(user.id, roleId),
    onSuccess: afterChange,
    onError: (err) => setError(getErrorMessage(err, "Error assigning role")),
  });

  const removeRole = useMutation({
    mutationFn: (roleId: number) => usersApi.removeRole(user.id, roleId),
    onSuccess: afterChange,
    onError: (err) => setError(getErrorMessage(err, "Error removing role")),
  });

  const busy = assign.isPending || removeRole.isPending;
  const current = userRoles.data ?? [];
  const available = (allRoles.data ?? []).filter((role) => !current.some((held) => held.id === role.id));

  return (
    <Modal isOpen onClose={onClose} title={`Manage Roles for ${user.email}`}>
      <ErrorAlert message={error} onDismiss={() => setError(null)} />
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div>
          <h3 className="text-lg font-semibold mb-3 text-gray-500">Current Roles</h3>
          <div className="space-y-2 max-h-60 overflow-y-auto" data-testid="current-roles">
            {userRoles.isPending && <p className="text-gray-500">Loading...</p>}
            {userRoles.isError && (
              <ErrorAlert message={getErrorMessage(userRoles.error, "Error loading the user's roles")} />
            )}
            {current.map((role) => (
              <div key={role.id} className="flex justify-between items-center p-3 bg-green-50 rounded border">
                <div>
                  <span
                    className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${roleBadgeClass(role.slug)}`}
                  >
                    {role.name}
                  </span>
                  <div className="text-sm text-gray-500 mt-1">{role.description || role.slug}</div>
                </div>
                <button
                  type="button"
                  onClick={() => removeRole.mutate(role.id)}
                  disabled={busy}
                  className="text-red-600 hover:text-red-800 text-sm font-medium disabled:opacity-50"
                >
                  Remove
                </button>
              </div>
            ))}
            {userRoles.isSuccess && current.length === 0 && <p className="text-gray-500">No roles assigned</p>}
          </div>
        </div>

        <div>
          <h3 className="text-lg font-semibold mb-3 text-gray-500">Available Roles</h3>
          <div className="space-y-2 max-h-60 overflow-y-auto" data-testid="available-roles">
            {allRoles.isPending && <p className="text-gray-500">Loading...</p>}
            {allRoles.isError && (
              <ErrorAlert message={getErrorMessage(allRoles.error, "Error loading roles")} />
            )}
            {available.map((role) => (
              <div key={role.id} className="flex justify-between items-center p-3 bg-gray-50 rounded border">
                <div>
                  <span
                    className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${roleBadgeClass(role.slug)}`}
                  >
                    {role.name}
                  </span>
                  <div className="text-sm text-gray-500 mt-1">{role.description || role.slug}</div>
                </div>
                <button
                  type="button"
                  onClick={() => assign.mutate(role.id)}
                  disabled={busy}
                  className="text-blue-600 hover:text-blue-800 text-sm font-medium disabled:opacity-50"
                >
                  Assign
                </button>
              </div>
            ))}
            {allRoles.isSuccess && userRoles.isSuccess && available.length === 0 && (
              <p className="text-gray-500">All roles assigned</p>
            )}
          </div>
        </div>
      </div>

      {user.permissions.length > 0 && (
        <div className="mt-6 pt-6 border-t">
          <h3 className="text-lg font-semibold mb-3 text-gray-500">Direct Permissions</h3>
          <div className="flex flex-wrap gap-2">
            {user.permissions.map((permission) => (
              <span key={permission.id} className="inline-flex items-center px-2 py-1 rounded text-xs bg-blue-100 text-blue-800">
                {permission.slug}
              </span>
            ))}
          </div>
        </div>
      )}
    </Modal>
  );
}
