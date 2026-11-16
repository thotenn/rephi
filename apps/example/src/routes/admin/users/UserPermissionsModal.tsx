import { useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { fetchMe, getErrorMessage, useAuthStore, usePermissions } from "@rephi/shared-components";
import { ErrorAlert, Modal } from "~/components/commons";
import { adminKeys, permissionsApi, usersApi } from "~/modules/api/admin";
import type { UserWithGrants } from "~/types/admin.types";

interface UserPermissionsModalProps {
  user: UserWithGrants;
  onClose: () => void;
}

export default function UserPermissionsModal({ user, onClose }: UserPermissionsModalProps) {
  const queryClient = useQueryClient();
  const { can } = usePermissions();
  const canAssign = can("permissions:assign");
  const canListPermissions = can("permissions:view");
  const currentUserId = useAuthStore((state) => state.user?.id);
  const [selected, setSelected] = useState("");
  const [error, setError] = useState<string | null>(null);

  const permissions = useQuery({
    queryKey: adminKeys.userPermissions(user.id),
    queryFn: () => usersApi.permissions(user.id),
  });
  const catalog = useQuery({
    queryKey: adminKeys.allPermissions,
    queryFn: permissionsApi.all,
    enabled: canAssign && canListPermissions,
  });

  const afterChange = () => {
    setError(null);
    setSelected("");
    queryClient.invalidateQueries({ queryKey: adminKeys.userPermissions(user.id) });
    queryClient.invalidateQueries({ queryKey: adminKeys.users });
    if (user.id === currentUserId) fetchMe().catch(() => {});
  };

  const grant = useMutation({
    mutationFn: (permissionId: number) => usersApi.grantPermission(user.id, permissionId),
    onSuccess: afterChange,
    onError: (err) => setError(getErrorMessage(err, "Error granting the permission")),
  });

  const revoke = useMutation({
    mutationFn: (permissionId: number) => usersApi.revokePermission(user.id, permissionId),
    onSuccess: afterChange,
    onError: (err) => setError(getErrorMessage(err, "Error revoking the permission")),
  });

  const busy = grant.isPending || revoke.isPending;
  const directIds = new Set((permissions.data?.direct ?? []).map((permission) => permission.id));
  const grantable = (catalog.data ?? []).filter((permission) => !directIds.has(permission.id));

  return (
    <Modal
      isOpen
      onClose={onClose}
      title={`Permissions of ${user.email}`}
      className="max-w-4xl max-h-[80vh] overflow-y-auto"
    >
      <ErrorAlert message={error} onDismiss={() => setError(null)} />

      {permissions.isPending ? (
        <p className="text-gray-500">Loading...</p>
      ) : permissions.isError ? (
        <ErrorAlert message={getErrorMessage(permissions.error, "Error loading the user's permissions")} />
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div>
            <h3 className="text-lg font-semibold mb-1 text-gray-500">Direct Permissions</h3>
            <p className="text-xs text-gray-500 mb-3">Granted to this user, on top of what its roles grant.</p>
            <div className="space-y-2" data-testid="direct-permissions">
              {permissions.data.direct.map((permission) => (
                <div key={permission.id} className="flex justify-between items-center p-2 bg-green-50 rounded">
                  <div>
                    <span className="font-medium text-gray-700">{permission.name}</span>
                    <span className="text-sm text-gray-500 ml-2">({permission.slug})</span>
                  </div>
                  {canAssign && (
                    <button
                      type="button"
                      onClick={() => revoke.mutate(permission.id)}
                      disabled={busy}
                      className="text-red-600 hover:text-red-800 text-sm disabled:opacity-50"
                    >
                      Revoke
                    </button>
                  )}
                </div>
              ))}
              {permissions.data.direct.length === 0 && <p className="text-gray-500">No direct permissions</p>}
            </div>

            {canAssign && canListPermissions && (
              <form
                className="mt-3 flex gap-2"
                onSubmit={(event) => {
                  event.preventDefault();
                  if (selected) grant.mutate(Number(selected));
                }}
              >
                <label htmlFor={`grant-permission-${user.id}`} className="sr-only">
                  Permission to grant
                </label>
                <select
                  id={`grant-permission-${user.id}`}
                  value={selected}
                  onChange={(event) => setSelected(event.target.value)}
                  disabled={!catalog.isSuccess}
                  className="flex-1 min-w-0 border rounded px-2 py-1 text-gray-900"
                  data-testid="grant-permission-select"
                >
                  <option value="">{catalog.isError ? "Could not load permissions" : "Grant a permission..."}</option>
                  {grantable.map((permission) => (
                    <option key={permission.id} value={permission.id}>
                      {permission.name} ({permission.slug})
                    </option>
                  ))}
                </select>
                <button
                  type="submit"
                  disabled={!selected || busy}
                  className="bg-blue-600 text-white px-3 py-1 rounded hover:bg-blue-700 disabled:opacity-50"
                >
                  Grant
                </button>
              </form>
            )}
          </div>

          <div>
            <h3 className="text-lg font-semibold mb-1 text-gray-500">Effective Permissions</h3>
            <p className="text-xs text-gray-500 mb-3">Everything this user may do, and where it comes from.</p>
            <div className="space-y-2 max-h-[28rem] overflow-y-auto" data-testid="effective-permissions">
              {permissions.data.effective.map((permission) => (
                <div key={permission.id} className="p-2 bg-gray-50 rounded" data-testid={`effective-${permission.slug}`}>
                  <span className="font-medium text-gray-700">{permission.name}</span>
                  <span className="text-sm text-gray-500 ml-2">({permission.slug})</span>
                  <div className="text-xs text-gray-500 mt-1">
                    {[
                      permission.direct ? "Direct" : null,
                      permission.roles.length > 0
                        ? `Role: ${permission.roles.map((source) => source.name).join(", ")}`
                        : null,
                    ]
                      .filter(Boolean)
                      .join(" · ")}
                  </div>
                </div>
              ))}
              {permissions.data.effective.length === 0 && <p className="text-gray-500">No permissions</p>}
            </div>
          </div>
        </div>
      )}
    </Modal>
  );
}
