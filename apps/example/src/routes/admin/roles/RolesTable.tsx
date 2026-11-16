import { TableCommon } from "~/components/commons";
import type { Role } from "~/types/admin.types";
import SystemBadge from "../shared/SystemBadge";

interface RolesTableProps {
  roles: Role[];
  canEdit: boolean;
  canDelete: boolean;
  onViewPermissions: (role: Role) => void;
  onEdit: (role: Role) => void;
  onDelete: (role: Role) => void;
}

const columns = [
  { key: "name", label: "Name" },
  { key: "slug", label: "Slug" },
  { key: "description", label: "Description" },
  { key: "actions", label: "Actions" },
];

export default function RolesTable({
  roles,
  canEdit,
  canDelete,
  onViewPermissions,
  onEdit,
  onDelete,
}: RolesTableProps) {
  return (
    <TableCommon columns={columns}>
      {roles.length > 0 ? (
        roles.map((role) => (
          <tr key={role.id} data-testid={`role-row-${role.slug}`}>
            <td className="px-6 py-4 whitespace-nowrap font-medium">
              {role.name}
              {role.is_system && <SystemBadge />}
            </td>
            <td className="px-6 py-4 whitespace-nowrap text-gray-500">{role.slug}</td>
            <td className="px-6 py-4 text-gray-500">{role.description || "-"}</td>
            <td className="px-6 py-4 whitespace-nowrap">
              <button
                type="button"
                onClick={() => onViewPermissions(role)}
                className="text-blue-600 hover:text-blue-800 mr-3"
              >
                Permissions
              </button>
              {canEdit && (
                <button
                  type="button"
                  onClick={() => onEdit(role)}
                  className="text-indigo-600 hover:text-indigo-800 mr-3"
                >
                  Edit
                </button>
              )}
              {canDelete && (
                <button
                  type="button"
                  onClick={() => onDelete(role)}
                  disabled={role.is_system}
                  title={role.is_system ? "System roles cannot be deleted" : undefined}
                  className="text-red-600 hover:text-red-800 disabled:text-gray-300 disabled:cursor-not-allowed"
                >
                  Delete
                </button>
              )}
            </td>
          </tr>
        ))
      ) : (
        <tr>
          <td colSpan={4} className="px-6 py-4 text-center text-gray-500">
            No roles found
          </td>
        </tr>
      )}
    </TableCommon>
  );
}
