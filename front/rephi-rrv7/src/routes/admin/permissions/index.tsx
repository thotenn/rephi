import { useState, useEffect } from "react";
import { permissionsApi } from "~/modules/api/admin";
import type { Permission } from "~/types/admin.types";

export default function PermissionsManagement() {
  const [permissions, setPermissions] = useState<Permission[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [showCreateForm, setShowCreateForm] = useState(false);
  const [editingPermission, setEditingPermission] = useState<Permission | null>(null);

  const [formData, setFormData] = useState({
    name: "",
    slug: "",
    description: "",
  });

  useEffect(() => {
    loadPermissions();
  }, []);

  const loadPermissions = async () => {
    try {
      const response = await permissionsApi.getAll();
      setPermissions(response.data);
    } catch (err) {
      setError("Error loading permissions");
    } finally {
      setLoading(false);
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      if (editingPermission) {
        await permissionsApi.update(editingPermission.id, formData);
      } else {
        await permissionsApi.create(formData);
      }
      resetForm();
      loadPermissions();
    } catch (err) {
      setError(editingPermission ? "Error updating permission" : "Error creating permission");
    }
  };

  const handleEdit = (permission: Permission) => {
    setEditingPermission(permission);
    setFormData({
      name: permission.name,
      slug: permission.slug,
      description: permission.description || "",
    });
    setShowCreateForm(true);
  };

  const handleDelete = async (permissionId: number) => {
    if (!confirm("Are you sure you want to delete this permission?")) return;
    
    try {
      await permissionsApi.delete(permissionId);
      loadPermissions();
    } catch (err) {
      setError("Error deleting permission");
    }
  };

  const resetForm = () => {
    setFormData({ name: "", slug: "", description: "" });
    setEditingPermission(null);
    setShowCreateForm(false);
  };

  const generateSlug = (name: string) => {
    return name.toLowerCase().replace(/\s+/g, "_").replace(/[^a-z0-9_:]/g, "");
  };

  const handleNameChange = (name: string) => {
    setFormData({
      ...formData,
      name,
      slug: generateSlug(name),
    });
  };

  const getPermissionCategory = (slug: string) => {
    const [category] = slug.split(":");
    return category;
  };

  const groupedPermissions = (permissions || []).reduce((acc, permission) => {
    const category = getPermissionCategory(permission.slug);
    if (!acc[category]) {
      acc[category] = [];
    }
    acc[category].push(permission);
    return acc;
  }, {} as Record<string, Permission[]>);

  if (loading) {
    return <div className="flex justify-center p-8">Loading...</div>;
  }

  return (
    <div className="max-w-6xl mx-auto p-6">
      <div className="flex justify-between items-center mb-6">
        <h1 className="text-3xl font-bold">Permissions Management</h1>
        <button
          onClick={() => setShowCreateForm(true)}
          className="bg-blue-600 text-white px-4 py-2 rounded hover:bg-blue-700"
        >
          Create Permission
        </button>
      </div>

      {error && (
        <div className="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded mb-4">
          {error}
        </div>
      )}

      {/* Create/Edit Form */}
      {showCreateForm && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 text-gray-500">
          <div className="bg-white p-6 rounded-lg w-full max-w-md">
            <h2 className="text-xl font-bold mb-4">
              {editingPermission ? "Edit Permission" : "Create Permission"}
            </h2>
            <form onSubmit={handleSubmit}>
              <div className="mb-4">
                <label htmlFor="permission-name" className="block text-sm font-medium mb-2">Name</label>
                <input
                  id="permission-name"
                  type="text"
                  value={formData.name}
                  onChange={(e) => handleNameChange(e.target.value)}
                  className="w-full border rounded px-3 py-2"
                  placeholder="e.g., Edit Users"
                  required
                />
              </div>
              <div className="mb-4">
                <label htmlFor="permission-slug" className="block text-sm font-medium mb-2">Slug</label>
                <input
                  id="permission-slug"
                  type="text"
                  value={formData.slug}
                  onChange={(e) => setFormData({ ...formData, slug: e.target.value })}
                  className="w-full border rounded px-3 py-2"
                  placeholder="e.g., users:edit"
                  required
                />
              </div>
                <p className="text-sm text-gray-500 mt-1" />
                  Use format: category:action (e.g., users:edit, roles:create)
              <div className="mb-4">
                <label htmlFor="permission-description" className="block text-sm font-medium mb-2">Description</label>
                <textarea
                  id="permission-description"
                  value={formData.description}
                  onChange={(e) => setFormData({ ...formData, description: e.target.value })}
                  className="w-full border rounded px-3 py-2"
                  rows={3}
                  placeholder="Describe what this permission allows"
                />
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
                  {editingPermission ? "Update" : "Create"}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Permissions by Category */}
      <div className="space-y-6">
        {Object.entries(groupedPermissions).map(([category, categoryPermissions]) => (
          <div key={category} className="bg-white rounded-lg shadow overflow-hidden">
            <div className="bg-gray-50 px-6 py-3 border-b">
              <h3 className="text-lg font-semibold capitalize">{category} Permissions</h3>
            </div>
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
                {categoryPermissions && categoryPermissions.length > 0 ? categoryPermissions.map((permission) => (
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
                        onClick={() => handleEdit(permission)}
                        className="text-indigo-600 hover:text-indigo-800 mr-3"
                      >
                        Edit
                      </button>
                      <button
                        onClick={() => handleDelete(permission.id)}
                        className="text-red-600 hover:text-red-800"
                      >
                        Delete
                      </button>
                    </td>
                  </tr>
                )) : (
                  <tr>
                    <td colSpan={4} className="px-6 py-4 text-center text-gray-500">
                      No permissions in this category
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        ))}
      </div>

      {permissions.length === 0 && !loading && (
        <div className="text-center py-12">
          <p className="text-gray-500 text-lg">No permissions found</p>
          <button
            onClick={() => setShowCreateForm(true)}
            className="mt-4 bg-blue-600 text-white px-6 py-2 rounded hover:bg-blue-700"
          >
            Create First Permission
          </button>
        </div>
      )}
    </div>
  );
}