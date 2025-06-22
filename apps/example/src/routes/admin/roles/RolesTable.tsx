import { TableCommon } from "~/components/commons";
import type { Role } from "~/types/admin.types";

interface RolesTableProps {
  roles: Role[];
  loading: boolean;
  onViewPermissions: (role: Role) => void;
  onEdit: (role: Role) => void;
  onDelete: (roleId: number) => void;
}

const columns = [
  { key: "name", label: "Name" },
  { key: "slug", label: "Slug" },
  { key: "description", label: "Description" },
  { key: "actions", label: "Actions" },
];

export default function RolesTable({ 
  roles, 
  loading, 
  onViewPermissions, 
  onEdit, 
  onDelete 
}: RolesTableProps) {
  if (loading) {
    return <div className="flex justify-center p-8">Loading...</div>;
  }

  return (
    <TableCommon columns={columns}>
      {roles && roles.length > 0 ? (
        roles.map((role) => (
          <tr key={role.id}>
            <td className="px-6 py-4 whitespace-nowrap font-medium">
              {role.name}
            </td>
            <td className="px-6 py-4 whitespace-nowrap text-gray-500">
              {role.slug}
            </td>
            <td className="px-6 py-4 text-gray-500">
              {role.description || "-"}
            </td>
            <td className="px-6 py-4 whitespace-nowrap">
              <button
                onClick={() => onViewPermissions(role)}
                className="text-blue-600 hover:text-blue-800 mr-3"
              >
                Permissions
              </button>
              <button
                onClick={() => onEdit(role)}
                className="text-indigo-600 hover:text-indigo-800 mr-3"
              >
                Edit
              </button>
              <button
                onClick={() => onDelete(role.id)}
                className="text-red-600 hover:text-red-800"
              >
                Delete
              </button>
            </td>
          </tr>
        ))
      ) : (
        <tr>
          <td
            colSpan={4}
            className="px-6 py-4 text-center text-gray-500"
          >
            {loading ? "Loading roles..." : "No roles found"}
          </td>
        </tr>
      )}
    </TableCommon>
  );
}