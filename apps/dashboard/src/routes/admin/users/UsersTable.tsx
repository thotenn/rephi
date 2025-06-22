import { TableCommon } from "~/components/commons";
import type { UserWithAuth } from "~/types/admin.types";

interface UsersTableProps {
  users: UserWithAuth[];
  loading: boolean;
  onViewUserRoles: (user: UserWithAuth) => void;
  formatDate: (dateString: string) => string;
  getRoleColor: (roleSlug: string) => string;
}

const columns = [
  { key: "user", label: "User" },
  { key: "roles", label: "Current Roles" },
  { key: "permissions", label: "Permissions Count" },
  { key: "joined", label: "Joined" },
  { key: "actions", label: "Actions" },
];

export default function UsersTable({ 
  users, 
  loading, 
  onViewUserRoles, 
  formatDate, 
  getRoleColor 
}: UsersTableProps) {
  if (loading) {
    return <div className="flex justify-center p-8">Loading...</div>;
  }

  return (
    <>
      <TableCommon columns={columns}>
        {(users || []).map((user) => (
          <tr key={user.id}>
            <td className="px-6 py-4 whitespace-nowrap">
              <div>
                <div className="font-medium text-gray-900">
                  {user.email}
                </div>
                <div className="text-sm text-gray-500">ID: {user.id}</div>
              </div>
            </td>
            <td className="px-6 py-4">
              <div className="flex flex-wrap gap-1">
                {user.roles && user.roles.length > 0 ? (
                  (user.roles || []).map((role) => (
                    <span
                      key={role.id}
                      className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${getRoleColor(
                        role.slug
                      )}`}
                    >
                      {role.name}
                    </span>
                  ))
                ) : (
                  <span className="text-gray-400 text-sm">No roles</span>
                )}
              </div>
            </td>
            <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
              {user.permissions ? user.permissions.length : 0}
            </td>
            <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
              {formatDate(user.inserted_at)}
            </td>
            <td className="px-6 py-4 whitespace-nowrap">
              <button
                onClick={() => onViewUserRoles(user)}
                className="text-blue-600 hover:text-blue-800"
              >
                Manage Roles
              </button>
            </td>
          </tr>
        ))}
      </TableCommon>

      {users.length === 0 && !loading && (
        <div className="text-center py-12">
          <p className="text-gray-500 text-lg">No users found</p>
        </div>
      )}
    </>
  );
}