import { Modal } from "~/components/commons";
import type { UserWithAuth, Role } from "~/types/admin.types";

interface UserRolesModalProps {
  selectedUser: UserWithAuth | null;
  userRoles: Role[];
  roles: Role[];
  onClose: () => void;
  onAssignRole: (roleId: number) => void;
  onRemoveRole: (roleId: number) => void;
  getRoleColor: (roleSlug: string) => string;
}

export default function UserRolesModal({
  selectedUser,
  userRoles,
  roles,
  onClose,
  onAssignRole,
  onRemoveRole,
  getRoleColor,
}: UserRolesModalProps) {
  return (
    <Modal
      isOpen={!!selectedUser}
      onClose={onClose}
      title={selectedUser ? `Manage Roles for ${selectedUser.email}` : ''}
    >
      {selectedUser && (
        <div>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            {/* Assigned Roles */}
            <div>
              <h3 className="text-lg font-semibold mb-3 text-gray-500">Current Roles</h3>
              <div className="space-y-2 max-h-60 overflow-y-auto">
                {(userRoles || []).map((role) => (
                  <div
                    key={role.id}
                    className="flex justify-between items-center p-3 bg-green-50 rounded border"
                  >
                    <div>
                      <span
                        className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${getRoleColor(
                          role.slug
                        )}`}
                      >
                        {role.name}
                      </span>
                      <div className="text-sm text-gray-500 mt-1">
                        {role.description || role.slug}
                      </div>
                    </div>
                    <button
                      onClick={() => onRemoveRole(role.id)}
                      className="text-red-600 hover:text-red-800 text-sm font-medium"
                      disabled={
                        role.slug === "admin" && userRoles.length === 1
                      }
                      title={
                        role.slug === "admin" && userRoles.length === 1
                          ? "Cannot remove the last admin role"
                          : "Remove role"
                      }
                    >
                      Remove
                    </button>
                  </div>
                ))}
                {(!userRoles || userRoles.length === 0) && (
                  <p className="text-gray-500">No roles assigned</p>
                )}
              </div>
            </div>

            {/* Available Roles */}
            <div>
              <h3 className="text-lg font-semibold mb-3 text-gray-500">
                Available Roles
              </h3>
              <div className="space-y-2 max-h-60 overflow-y-auto">
                {(roles || [])
                  .filter(
                    (role) =>
                      !(userRoles || []).some((ur) => ur.id === role.id)
                  )
                  .map((role) => (
                    <div
                      key={role.id}
                      className="flex justify-between items-center p-3 bg-gray-50 rounded border"
                    >
                      <div>
                        <span
                          className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${getRoleColor(
                            role.slug
                          )}`}
                        >
                          {role.name}
                        </span>
                        <div className="text-sm text-gray-500 mt-1">
                          {role.description || role.slug}
                        </div>
                      </div>
                      <button
                        onClick={() => onAssignRole(role.id)}
                        className="text-blue-600 hover:text-blue-800 text-sm font-medium"
                      >
                        Assign
                      </button>
                    </div>
                  ))}
                {(roles || []).filter(
                  (role) =>
                    !(userRoles || []).some((ur) => ur.id === role.id)
                ).length === 0 && (
                  <p className="text-gray-500">All roles assigned</p>
                )}
              </div>
            </div>
          </div>

          {/* User Permissions Preview */}
          {selectedUser.permissions &&
            selectedUser.permissions.length > 0 && (
              <div className="mt-6 pt-6 border-t">
                <h3 className="text-lg font-semibold mb-3">
                  Current Permissions
                </h3>
                <div className="flex flex-wrap gap-2">
                  {(selectedUser.permissions || []).map((permission) => (
                    <span
                      key={permission.id}
                      className="inline-flex items-center px-2 py-1 rounded text-xs bg-blue-100 text-blue-800"
                    >
                      {permission.slug}
                    </span>
                  ))}
                </div>
              </div>
            )}
        </div>
      )}
    </Modal>
  );
}