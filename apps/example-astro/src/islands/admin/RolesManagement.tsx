import { useState, useEffect, type SubmitEventHandler } from "react";
import IslandProviders from "~/components/react/IslandProviders";
import { describeError } from "~/lib/errors";
import { rolesApi, permissionsApi } from "~/lib/api/admin";
import type { Role, Permission } from "~/types/admin.types";
import RolesTable from "./RolesTable";
import CreateEditRoleModal from "./CreateEditRoleModal";
import RolePermissionsModal from "./RolePermissionsModal";

function RolesManagementScreen() {
  const [roles, setRoles] = useState<Role[]>([]);
  const [permissions, setPermissions] = useState<Permission[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [showCreateForm, setShowCreateForm] = useState(false);
  const [editingRole, setEditingRole] = useState<Role | null>(null);
  const [selectedRole, setSelectedRole] = useState<Role | null>(null);
  const [rolePermissions, setRolePermissions] = useState<Permission[]>([]);

  const [formData, setFormData] = useState({
    name: "",
    slug: "",
    description: "",
  });

  const loadRoles = async () => {
    try {
      const response = await rolesApi.getAll();
      setRoles(response.data);
    } catch (err) {
      setError(describeError("Error loading roles", err));
    } finally {
      setLoading(false);
    }
  };

  const loadPermissions = async () => {
    try {
      const response = await permissionsApi.getAll();
      setPermissions(response.data);
    } catch (err) {
      console.error("Error loading permissions:", err);
    }
  };

  useEffect(() => {
    // The loader only sets state after its request settles, which the rule cannot
    // see through the async call. Moving these fetches to react-query removes this.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    loadRoles();
    loadPermissions();
  }, []);

  const loadRolePermissions = async (roleId: number) => {
    try {
      const response = await rolesApi.getPermissions(roleId);
      setRolePermissions(response.data);
    } catch (err) {
      console.error("Error loading role permissions:", err);
    }
  };

  const handleSubmit: SubmitEventHandler<HTMLFormElement> = async (e) => {
    e.preventDefault();
    try {
      if (editingRole) {
        await rolesApi.update(editingRole.id, formData);
      } else {
        await rolesApi.create(formData);
      }
      resetForm();
      loadRoles();
    } catch (err) {
      setError(describeError(editingRole ? "Error updating role" : "Error creating role", err));
    }
  };

  const handleEdit = (role: Role) => {
    setEditingRole(role);
    setFormData({
      name: role.name,
      slug: role.slug,
      description: role.description || "",
    });
    setShowCreateForm(true);
  };

  const handleDelete = async (roleId: number) => {
    if (!confirm("Are you sure you want to delete this role?")) return;

    try {
      await rolesApi.delete(roleId);
      loadRoles();
    } catch (err) {
      setError(describeError("Error deleting role", err));
    }
  };

  const handleViewPermissions = async (role: Role) => {
    setSelectedRole(role);
    await loadRolePermissions(role.id);
  };

  const handleAssignPermission = async (permissionId: number) => {
    if (!selectedRole) return;

    try {
      await rolesApi.assignPermission(selectedRole.id, permissionId);
      await loadRolePermissions(selectedRole.id);
    } catch (err) {
      setError(describeError("Error assigning permission", err));
    }
  };

  const handleRemovePermission = async (permissionId: number) => {
    if (!selectedRole) return;

    try {
      await rolesApi.removePermission(selectedRole.id, permissionId);
      await loadRolePermissions(selectedRole.id);
    } catch (err) {
      setError(describeError("Error removing permission", err));
    }
  };

  const resetForm = () => {
    setFormData({ name: "", slug: "", description: "" });
    setEditingRole(null);
    setShowCreateForm(false);
  };

  const generateSlug = (name: string) => {
    return name
      .toLowerCase()
      .replace(/\s+/g, "_")
      .replace(/[^a-z0-9_]/g, "");
  };

  const handleNameChange = (name: string) => {
    setFormData({
      ...formData,
      name,
      slug: generateSlug(name),
    });
  };

  const handleFormDataChange = (field: string, value: string) => {
    setFormData({
      ...formData,
      [field]: value,
    });
  };

  if (loading) {
    return <div className="flex justify-center p-8">Loading...</div>;
  }

  return (
    <div className="max-w-6xl mx-auto p-6 text-gray-500">
      <div className="flex justify-between items-center mb-6">
        <h1 className="text-3xl font-bold">Roles Management</h1>
        <button
          onClick={() => setShowCreateForm(true)}
          className="bg-blue-600 text-white px-4 py-2 rounded hover:bg-blue-700"
        >
          Create Role
        </button>
      </div>

      {error && (
        <div className="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded mb-4">
          {error}
        </div>
      )}

      <CreateEditRoleModal
        isOpen={showCreateForm}
        editingRole={editingRole}
        formData={formData}
        onClose={resetForm}
        onSubmit={handleSubmit}
        onNameChange={handleNameChange}
        onFormDataChange={handleFormDataChange}
      />

      <RolesTable
        roles={roles}
        loading={loading}
        onViewPermissions={handleViewPermissions}
        onEdit={handleEdit}
        onDelete={handleDelete}
      />

      <RolePermissionsModal
        selectedRole={selectedRole}
        rolePermissions={rolePermissions}
        permissions={permissions}
        onClose={() => setSelectedRole(null)}
        onAssignPermission={handleAssignPermission}
        onRemovePermission={handleRemovePermission}
      />
    </div>
  );
}

/** Roles CRUD with the permission assignment modal. */
export default function RolesManagement() {
  return (
    <IslandProviders>
      <RolesManagementScreen />
    </IslandProviders>
  );
}
