import { Modal } from "~/components/commons";
import type { Role, Permission } from "~/types/admin.types";

interface RolePermissionsModalProps {
  selectedRole: Role | null;
  rolePermissions: Permission[];
  permissions: Permission[];
  onClose: () => void;
  onAssignPermission: (permissionId: number) => void;
  onRemovePermission: (permissionId: number) => void;
}

export default function RolePermissionsModal({
  selectedRole,
  rolePermissions,
  permissions,
  onClose,
  onAssignPermission,
  onRemovePermission,
}: RolePermissionsModalProps) {
  return (
    <Modal
      isOpen={!!selectedRole}
      onClose={onClose}
      title={selectedRole ? `Permissions for ${selectedRole.name}` : undefined}
      className="max-w-4xl max-h-[80vh] overflow-y-auto"
    >
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        {/* Assigned Permissions */}
        <div>
          <h3 className="text-lg font-semibold mb-3 text-gray-500">
            Assigned Permissions
          </h3>
          <div className="space-y-2 max-h-60 overflow-y-auto">
            {(rolePermissions || []).map((permission) => (
              <div
                key={permission.id}
                className="flex justify-between items-center p-2 bg-green-50 rounded"
              >
                <div>
                  <span className="font-medium">{permission.name}</span>
                  <span className="text-sm text-gray-500 ml-2">
                    ({permission.slug})
                  </span>
                </div>
                <button
                  onClick={() => onRemovePermission(permission.id)}
                  className="text-red-600 hover:text-red-800 text-sm"
                >
                  Remove
                </button>
              </div>
            ))}
            {(!rolePermissions || rolePermissions.length === 0) && (
              <p className="text-gray-500">No permissions assigned</p>
            )}
          </div>
        </div>

        {/* Available Permissions */}
        <div>
          <h3 className="text-lg font-semibold mb-3 text-gray-500">
            Available Permissions
          </h3>
          <div className="space-y-2 max-h-60 overflow-y-auto">
            {(permissions || [])
              .filter(
                (p) =>
                  !(rolePermissions || []).some((rp) => rp.id === p.id)
              )
              .map((permission) => (
                <div
                  key={permission.id}
                  className="flex justify-between items-center p-2 bg-gray-50 rounded"
                >
                  <div>
                    <span className="font-medium">
                      {permission.name}
                    </span>
                    <span className="text-sm text-gray-500 ml-2">
                      ({permission.slug})
                    </span>
                  </div>
                  <button
                    onClick={() =>
                      onAssignPermission(permission.id)
                    }
                    className="text-blue-600 hover:text-blue-800 text-sm"
                  >
                    Assign
                  </button>
                </div>
              ))}
          </div>
        </div>
      </div>
    </Modal>
  );
}