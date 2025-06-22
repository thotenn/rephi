import { TableCommon } from "~/components/commons";
import type { Permission } from "~/types/admin.types";

interface PermissionsTableProps {
  permissions: Permission[];
  loading: boolean;
  onEdit: (permission: Permission) => void;
  onDelete: (permissionId: number) => void;
  onCreateFirst: () => void;
  getPermissionCategory: (slug: string) => string;
}

const columns = [
  { key: "name", label: "Name" },
  { key: "slug", label: "Slug" },
  { key: "description", label: "Description" },
  { key: "actions", label: "Actions" },
];

export default function PermissionsTable({ 
  permissions, 
  loading, 
  onEdit, 
  onDelete, 
  onCreateFirst,
  getPermissionCategory 
}: PermissionsTableProps) {
  if (loading) {
    return <div className="flex justify-center p-8">Loading...</div>;
  }

  const groupedPermissions = (permissions || []).reduce((acc, permission) => {
    const category = getPermissionCategory(permission.slug);
    if (!acc[category]) {
      acc[category] = [];
    }
    acc[category].push(permission);
    return acc;
  }, {} as Record<string, Permission[]>);

  if (permissions.length === 0 && !loading) {
    return (
      <div className="text-center py-12">
        <p className="text-gray-500 text-lg">No permissions found</p>
        <button
          onClick={onCreateFirst}
          className="mt-4 bg-blue-600 text-white px-6 py-2 rounded hover:bg-blue-700"
        >
          Create First Permission
        </button>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {Object.entries(groupedPermissions).map(
        ([category, categoryPermissions]) => (
          <div
            key={category}
            className="bg-white rounded-lg shadow overflow-hidden"
          >
            <div className="bg-gray-50 px-6 py-3 border-b">
              <h3 className="text-lg font-semibold capitalize text-gray-500">
                {category} Permissions
              </h3>
            </div>
            <TableCommon columns={columns}>
              {categoryPermissions && categoryPermissions.length > 0 ? (
                categoryPermissions.map((permission) => (
                  <tr key={permission.id}>
                    <td className="px-6 py-4 whitespace-nowrap font-medium text-gray-500">
                      {permission.name}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <code className="bg-gray-100 px-2 py-1 rounded text-sm text-gray-700">
                        {permission.slug}
                      </code>
                    </td>
                    <td className="px-6 py-4 text-gray-500">
                      {permission.description || "-"}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <button
                        onClick={() => onEdit(permission)}
                        className="text-indigo-600 hover:text-indigo-800 mr-3"
                      >
                        Edit
                      </button>
                      <button
                        onClick={() => onDelete(permission.id)}
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
                    No permissions in this category
                  </td>
                </tr>
              )}
            </TableCommon>
          </div>
        )
      )}
    </div>
  );
}