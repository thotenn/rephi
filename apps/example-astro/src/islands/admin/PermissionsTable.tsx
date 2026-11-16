import { TableCommon } from "~/components/react";
import type { Permission } from "~/types/admin.types";
import SystemBadge from "./shared/SystemBadge";

interface PermissionsTableProps {
  permissions: Permission[];
  canEdit: boolean;
  canDelete: boolean;
  onEdit: (permission: Permission) => void;
  onDelete: (permission: Permission) => void;
}

const columns = [
  { key: "name", label: "Name" },
  { key: "slug", label: "Slug" },
  { key: "description", label: "Description" },
  { key: "actions", label: "Actions" },
];

/** The slug's first segment: "users:edit" -> "users". */
const categoryOf = (slug: string) => slug.split(":")[0];

/** One page of permissions, grouped by category. */
export default function PermissionsTable({
  permissions,
  canEdit,
  canDelete,
  onEdit,
  onDelete,
}: PermissionsTableProps) {
  if (permissions.length === 0) {
    return (
      <div className="text-center py-12">
        <p className="text-gray-500 text-lg">No permissions found</p>
      </div>
    );
  }

  const groups = permissions.reduce<Record<string, Permission[]>>((acc, permission) => {
    (acc[categoryOf(permission.slug)] ??= []).push(permission);
    return acc;
  }, {});

  return (
    <div className="space-y-6">
      {Object.entries(groups).map(([category, categoryPermissions]) => (
        <div key={category} className="bg-white rounded-lg shadow overflow-hidden">
          <div className="bg-gray-50 px-6 py-3 border-b">
            <h3 className="text-lg font-semibold capitalize text-gray-500">{category} Permissions</h3>
          </div>
          <TableCommon columns={columns}>
            {categoryPermissions.map((permission) => (
              <tr key={permission.id} data-testid={`permission-row-${permission.slug}`}>
                <td className="px-6 py-4 whitespace-nowrap font-medium text-gray-500">
                  {permission.name}
                  {permission.is_system && <SystemBadge />}
                </td>
                <td className="px-6 py-4 whitespace-nowrap">
                  <code className="bg-gray-100 px-2 py-1 rounded text-sm text-gray-700">
                    {permission.slug}
                  </code>
                </td>
                <td className="px-6 py-4 text-gray-500">{permission.description || "-"}</td>
                <td className="px-6 py-4 whitespace-nowrap">
                  {canEdit && (
                    <button
                      type="button"
                      onClick={() => onEdit(permission)}
                      className="text-indigo-600 hover:text-indigo-800 mr-3"
                    >
                      Edit
                    </button>
                  )}
                  {canDelete && (
                    <button
                      type="button"
                      onClick={() => onDelete(permission)}
                      disabled={permission.is_system}
                      title={permission.is_system ? "System permissions cannot be deleted" : undefined}
                      className="text-red-600 hover:text-red-800 disabled:text-gray-300 disabled:cursor-not-allowed"
                    >
                      Delete
                    </button>
                  )}
                  {!canEdit && !canDelete && <span className="text-gray-400 text-sm">Read only</span>}
                </td>
              </tr>
            ))}
          </TableCommon>
        </div>
      ))}
    </div>
  );
}
