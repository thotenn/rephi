import { useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { fetchMe, getErrorMessage, usePermissions } from "~/lib/rephi";
import { ErrorAlert, Modal } from "~/components/react";
import { adminKeys, permissionsApi, rolesApi } from "~/lib/api/admin";
import type { Role } from "~/types/admin.types";
import RoleParentsSection from "./RoleParentsSection";

interface RolePermissionsModalProps {
  role: Role;
  onClose: () => void;
}

export default function RolePermissionsModal({ role, onClose }: RolePermissionsModalProps) {
  const queryClient = useQueryClient();
  const { can } = usePermissions();
  const canAssign = can("permissions:assign");
  const canListPermissions = can("permissions:view");
  const [error, setError] = useState<string | null>(null);

  const detail = useQuery({ queryKey: adminKeys.role(role.id), queryFn: () => rolesApi.get(role.id) });
  const catalog = useQuery({
    queryKey: adminKeys.allPermissions,
    queryFn: permissionsApi.all,
    enabled: canAssign && canListPermissions,
  });

  const afterChange = () => {
    setError(null);
    queryClient.invalidateQueries({ queryKey: adminKeys.role(role.id) });
    // The signed-in user may hold this role: refresh their permissions.
    fetchMe().catch(() => {});
  };

  const assign = useMutation({
    mutationFn: (permissionId: number) => rolesApi.assignPermission(role.id, permissionId),
    onSuccess: afterChange,
    onError: (err) => setError(getErrorMessage(err, "Error assigning permission")),
  });

  const removePermission = useMutation({
    mutationFn: (permissionId: number) => rolesApi.removePermission(role.id, permissionId),
    onSuccess: afterChange,
    onError: (err) => setError(getErrorMessage(err, "Error removing permission")),
  });

  const busy = assign.isPending || removePermission.isPending;
  const held = new Set([
    ...(detail.data?.permissions ?? []).map((p) => p.id),
    ...(detail.data?.inherited_permissions ?? []).map((p) => p.id),
  ]);
  const available = (catalog.data ?? []).filter((p) => !held.has(p.id));

  return (
    <Modal
      isOpen
      onClose={onClose}
      title={`Permissions for ${role.name}`}
      className="max-w-4xl max-h-[80vh] overflow-y-auto"
    >
      <RoleParentsSection role={role} />

      <ErrorAlert message={error} onDismiss={() => setError(null)} />

      {detail.isPending ? (
        <p className="text-gray-500">Loading...</p>
      ) : detail.isError ? (
        <ErrorAlert message={getErrorMessage(detail.error, "Error loading the role")} />
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div>
            <h3 className="text-lg font-semibold mb-3 text-gray-500">Assigned Permissions</h3>
            <div className="space-y-2 max-h-60 overflow-y-auto" data-testid="assigned-permissions">
              {detail.data.permissions.map((permission) => (
                <div key={permission.id} className="flex justify-between items-center p-2 bg-green-50 rounded">
                  <div>
                    <span className="font-medium text-gray-700">{permission.name}</span>
                    <span className="text-sm text-gray-500 ml-2">({permission.slug})</span>
                  </div>
                  {canAssign && (
                    <button
                      type="button"
                      onClick={() => removePermission.mutate(permission.id)}
                      disabled={busy}
                      className="text-red-600 hover:text-red-800 text-sm disabled:opacity-50"
                    >
                      Remove
                    </button>
                  )}
                </div>
              ))}
              {detail.data.permissions.length === 0 && (
                <p className="text-gray-500">No permissions assigned</p>
              )}
            </div>

            <h3 className="text-lg font-semibold mt-6 mb-3 text-gray-500">Inherited Permissions</h3>
            <div className="space-y-2 max-h-60 overflow-y-auto" data-testid="inherited-permissions">
              {detail.data.inherited_permissions.map((permission) => (
                <div key={permission.id} className="p-2 bg-gray-50 rounded">
                  <span className="font-medium text-gray-700">{permission.name}</span>
                  <span className="text-sm text-gray-500 ml-2">({permission.slug})</span>
                  <div className="text-xs text-gray-500 mt-1">
                    Inherited from {permission.inherited_from.map((source) => source.name).join(", ")}
                  </div>
                </div>
              ))}
              {detail.data.inherited_permissions.length === 0 && (
                <p className="text-gray-500">No inherited permissions</p>
              )}
            </div>
          </div>

          <div>
            <h3 className="text-lg font-semibold mb-3 text-gray-500">Available Permissions</h3>
            {!canAssign || !canListPermissions ? (
              <p className="text-gray-500 text-sm">
                You can view this role&apos;s permissions but not change them.
              </p>
            ) : catalog.isPending ? (
              <p className="text-gray-500">Loading...</p>
            ) : catalog.isError ? (
              <ErrorAlert message={getErrorMessage(catalog.error, "Error loading permissions")} />
            ) : (
              <div className="space-y-2 max-h-[28rem] overflow-y-auto" data-testid="available-permissions">
                {available.map((permission) => (
                  <div key={permission.id} className="flex justify-between items-center p-2 bg-gray-50 rounded">
                    <div>
                      <span className="font-medium text-gray-700">{permission.name}</span>
                      <span className="text-sm text-gray-500 ml-2">({permission.slug})</span>
                    </div>
                    <button
                      type="button"
                      onClick={() => assign.mutate(permission.id)}
                      disabled={busy}
                      className="text-blue-600 hover:text-blue-800 text-sm disabled:opacity-50"
                    >
                      Assign
                    </button>
                  </div>
                ))}
                {available.length === 0 && <p className="text-gray-500">Every permission is granted</p>}
              </div>
            )}
          </div>
        </div>
      )}
    </Modal>
  );
}
