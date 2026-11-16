import { TableCommon } from "~/components/react";
import type { UserWithGrants } from "~/types/admin.types";
import { roleBadgeClass } from "~/lib/roles";

interface UsersTableProps {
  users: UserWithGrants[];
  currentUserId: number | undefined;
  canManageRoles: boolean;
  canEdit: boolean;
  canDelete: boolean;
  /** `users:reset_password`; never offered on the signed-in user's own row. */
  canResetPassword: boolean;
  onManageRoles: (user: UserWithGrants) => void;
  onViewPermissions: (user: UserWithGrants) => void;
  onEdit: (user: UserWithGrants) => void;
  onResetPassword: (user: UserWithGrants) => void;
  onDelete: (user: UserWithGrants) => void;
}

const columns = [
  { key: "user", label: "User" },
  { key: "roles", label: "Current Roles" },
  { key: "permissions", label: "Direct Permissions" },
  { key: "joined", label: "Joined" },
  { key: "actions", label: "Actions" },
];

const formatDate = (value: string) => new Date(value).toLocaleDateString();

export default function UsersTable({
  users,
  currentUserId,
  canManageRoles,
  canEdit,
  canDelete,
  canResetPassword,
  onManageRoles,
  onViewPermissions,
  onEdit,
  onResetPassword,
  onDelete,
}: UsersTableProps) {
  if (users.length === 0) {
    return (
      <div className="text-center py-12">
        <p className="text-gray-500 text-lg">No users found</p>
      </div>
    );
  }

  return (
    <TableCommon columns={columns}>
      {users.map((user) => (
        <tr key={user.id} data-testid={`user-row-${user.email}`}>
          <td className="px-6 py-4 whitespace-nowrap">
            <div className="font-medium text-gray-900">
              {user.email}
              {user.id === currentUserId && <span className="ml-2 text-xs text-gray-500">(you)</span>}
            </div>
            {user.must_change_password && (
              <div className="mt-1">
                <span
                  className="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-yellow-100 text-yellow-800"
                  title="Its password was reset; it has not chosen a new one yet"
                >
                  Must change password
                </span>
              </div>
            )}
            <div className="text-sm text-gray-500">ID: {user.id}</div>
          </td>
          <td className="px-6 py-4">
            <div className="flex flex-wrap gap-1">
              {user.roles.length > 0 ? (
                user.roles.map((role) => (
                  <span
                    key={role.id}
                    className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${roleBadgeClass(role.slug)}`}
                  >
                    {role.name}
                  </span>
                ))
              ) : (
                <span className="text-gray-400 text-sm">No roles</span>
              )}
            </div>
          </td>
          <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">{user.permissions.length}</td>
          <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">{formatDate(user.inserted_at)}</td>
          <td className="px-6 py-4 whitespace-nowrap text-sm">
            <button
              type="button"
              onClick={() => onViewPermissions(user)}
              className="text-blue-600 hover:text-blue-800 mr-3"
            >
              Permissions
            </button>
            {canManageRoles && (
              <button
                type="button"
                onClick={() => onManageRoles(user)}
                className="text-blue-600 hover:text-blue-800 mr-3"
              >
                Manage Roles
              </button>
            )}
            {canEdit && (
              <button
                type="button"
                onClick={() => onEdit(user)}
                className="text-indigo-600 hover:text-indigo-800 mr-3"
              >
                Edit
              </button>
            )}
            {canResetPassword && user.id !== currentUserId && (
              <button
                type="button"
                onClick={() => onResetPassword(user)}
                className="text-orange-600 hover:text-orange-800 mr-3"
              >
                Reset password
              </button>
            )}
            {canDelete && (
              <button
                type="button"
                onClick={() => onDelete(user)}
                className="text-red-600 hover:text-red-800"
              >
                Delete
              </button>
            )}
          </td>
        </tr>
      ))}
    </TableCommon>
  );
}
