import { useState, useEffect } from "react";
import { rolesApi, permissionsApi } from "~/modules/api/admin";
import type { Role, Permission } from "~/types/admin.types";

export default function RolesManagement() {
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

  useEffect(() => {
    loadRoles();
    loadPermissions();
  }, []);

  const loadRoles = async () => {
    try {
      const response = await rolesApi.getAll();
      setRoles(response.data);
    } catch (err) {
      setError("Error loading roles");
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

  const loadRolePermissions = async (roleId: number) => {
    try {
      const response = await rolesApi.getPermissions(roleId);
      setRolePermissions(response.data);
    } catch (err) {
      console.error("Error loading role permissions:", err);
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
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
      setError(editingRole ? "Error updating role" : "Error creating role");
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
      setError("Error deleting role");
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
      setError("Error assigning permission");
    }
  };

  const handleRemovePermission = async (permissionId: number) => {
    if (!selectedRole) return;
    
    try {
      await rolesApi.removePermission(selectedRole.id, permissionId);
      await loadRolePermissions(selectedRole.id);
    } catch (err) {
      setError("Error removing permission");
    }
  };

  const resetForm = () => {
    setFormData({ name: "", slug: "", description: "" });
    setEditingRole(null);
    setShowCreateForm(false);
  };

  const generateSlug = (name: string) => {
    return name.toLowerCase().replace(/\s+/g, "_").replace(/[^a-z0-9_]/g, "");
  };

  const handleNameChange = (name: string) => {
    setFormData({
      ...formData,
      name,
      slug: generateSlug(name),
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

      {/* Create/Edit Form */}
      {showCreateForm && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div className="bg-white p-6 rounded-lg w-full max-w-md">
            <h2 className="text-xl font-bold mb-4">
              {editingRole ? "Edit Role" : "Create Role"}
            </h2>
            <form onSubmit={handleSubmit}>
              <div className="mb-4">
                <label htmlFor="role-name" className="block text-sm font-medium mb-2">Name</label>
                <input
                  id="role-name"
                  type="text"
                  value={formData.name}
                  onChange={(e) => handleNameChange(e.target.value)}
                  className="w-full border rounded px-3 py-2"
                  required
                />
              </div>
              <div className="mb-4">
                <label htmlFor="role-slug" className="block text-sm font-medium mb-2">Slug</label>
                <input
                  id="role-slug"
                  type="text"
                  value={formData.slug}
                  onChange={(e) => setFormData({ ...formData, slug: e.target.value })}
                  className="w-full border rounded px-3 py-2"
                  required
                />
              <div className="mb-4">
                <label htmlFor="role-description" className="block text-sm font-medium mb-2">Description</label>
                <textarea
                  id="role-description"
                  value={formData.description}
                  onChange={(e) => setFormData({ ...formData, description: e.target.value })}
                  className="w-full border rounded px-3 py-2"
                  rows={3}
                />
              </div>
              </div>
              <div className="flex justify-end gap-2">
                <button
                  type="button"
                  onClick={resetForm}
                  className="px-4 py-2 border rounded hover:bg-gray-50"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="bg-blue-600 text-white px-4 py-2 rounded hover:bg-blue-700"
                >
                  {editingRole ? "Update" : "Create"}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Roles Table */}
      <div className="bg-white rounded-lg shadow overflow-hidden">
        <table className="w-full">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                Name
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                Slug
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                Description
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                Actions
              </th>
            </tr>
          </thead>
          <tbody className="bg-white divide-y divide-gray-200">
            {roles && roles.length > 0 ? roles.map((role) => (
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
                    onClick={() => handleViewPermissions(role)}
                    className="text-blue-600 hover:text-blue-800 mr-3"
                  >
                    Permissions
                  </button>
                  <button
                    onClick={() => handleEdit(role)}
                    className="text-indigo-600 hover:text-indigo-800 mr-3"
                  >
                    Edit
                  </button>
                  <button
                    onClick={() => handleDelete(role.id)}
                    className="text-red-600 hover:text-red-800"
                  >
                    Delete
                  </button>
                </td>
              </tr>
            )) : (
              <tr>
                <td colSpan={4} className="px-6 py-4 text-center text-gray-500">
                  {loading ? "Loading roles..." : "No roles found"}
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>

      {/* Role Permissions Modal */}
      {selectedRole && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div className="bg-white p-6 rounded-lg w-full max-w-4xl max-h-[80vh] overflow-y-auto">
            <div className="flex justify-between items-center mb-4">
              <h2 className="text-xl font-bold">
                Permissions for {selectedRole.name}
              </h2>
              <button
                onClick={() => setSelectedRole(null)}
                className="text-gray-500 hover:text-gray-700"
              >
                ✕
              </button>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              {/* Assigned Permissions */}
              <div>
                <h3 className="text-lg font-semibold mb-3">Assigned Permissions</h3>
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
                        onClick={() => handleRemovePermission(permission.id)}
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
                <h3 className="text-lg font-semibold mb-3">Available Permissions</h3>
                <div className="space-y-2 max-h-60 overflow-y-auto">
                  {(permissions || [])
                    .filter((p) => !(rolePermissions || []).some((rp) => rp.id === p.id))
                    .map((permission) => (
                      <div
                        key={permission.id}
                        className="flex justify-between items-center p-2 bg-gray-50 rounded"
                      >
                        <div>
                          <span className="font-medium">{permission.name}</span>
                          <span className="text-sm text-gray-500 ml-2">
                            ({permission.slug})
                          </span>
                        </div>
                        <button
                          onClick={() => handleAssignPermission(permission.id)}
                          className="text-blue-600 hover:text-blue-800 text-sm"
                        >
                          Assign
                        </button>
                      </div>
                    ))}
                </div>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}