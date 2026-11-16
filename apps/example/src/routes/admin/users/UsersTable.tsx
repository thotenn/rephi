import { TableCommon } from "~/components/commons";
import type { UserWithGrants } from "~/types/admin.types";
import { roleBadgeClass } from "~/utils/roles";

interface UsersTableProps {
  users: UserWithGrants[];
  currentUserId: number | undefined;
  canManageRoles: boolean;
  canEdit: boolean;
  canDelete: boolean;
  onManageRoles: (user: UserWithGrants) => void;
  onEdit: (user: UserWithGrants) => void;
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
  onManageRoles,
  onEdit,
  onDelete,
}: UsersTableProps) {
  if (users.length === 0) {
    return (
      <div className="text-center py-12">
        <p className="text-gray-500 text-lg">No users found</p>
      </div>
    );
  }

  const readOnly = !canManageRoles && !canEdit && !canDelete;

  return (
    <TableCommon columns={columns}>
      {users.map((user) => (
        <tr key={user.id} data-testid={`user-row-${user.email}`}>
          <td className="px-6 py-4 whitespace-nowrap">
            <div className="font-medium text-gray-900">
              {user.email}
              {user.id === currentUserId && <span className="ml-2 text-xs text-gray-500">(you)</span>}
            </div>
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
            {canDelete && (
              <button
                type="button"
                onClick={() => onDelete(user)}
                className="text-red-600 hover:text-red-800"
              >
                Delete
              </button>
            )}
            {readOnly && <span className="text-gray-400">Read only</span>}
          </td>
        </tr>
      ))}
    </TableCommon>
  );
}
