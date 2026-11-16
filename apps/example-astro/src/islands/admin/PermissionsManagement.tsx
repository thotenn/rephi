import { useState, useEffect, type SubmitEventHandler } from "react";
import IslandProviders from "~/components/react/IslandProviders";
import { describeError } from "~/lib/errors";
import { permissionsApi } from "~/lib/api/admin";
import type { Permission } from "~/types/admin.types";
import PermissionsTable from "./PermissionsTable";
import CreateEditPermissionModal from "./CreateEditPermissionModal";

function PermissionsManagementScreen() {
  const [permissions, setPermissions] = useState<Permission[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [showCreateForm, setShowCreateForm] = useState(false);
  const [editingPermission, setEditingPermission] = useState<Permission | null>(
    null
  );

  const [formData, setFormData] = useState({
    name: "",
    slug: "",
    description: "",
  });

  const loadPermissions = async () => {
    try {
      const response = await permissionsApi.getAll();
      setPermissions(response.data);
    } catch (err) {
      setError(describeError("Error loading permissions", err));
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    // The loader only sets state after its request settles, which the rule cannot
    // see through the async call. Moving these fetches to react-query removes this.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    loadPermissions();
  }, []);

  const handleSubmit: SubmitEventHandler<HTMLFormElement> = async (e) => {
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
      setError(describeError(editingPermission ? "Error updating permission" : "Error creating permission", err));
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
      setError(describeError("Error deleting permission", err));
    }
  };

  const resetForm = () => {
    setFormData({ name: "", slug: "", description: "" });
    setEditingPermission(null);
    setShowCreateForm(false);
  };

  const generateSlug = (name: string) => {
    return name
      .toLowerCase()
      .replace(/\s+/g, "_")
      .replace(/[^a-z0-9_:]/g, "");
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

  const getPermissionCategory = (slug: string) => {
    const [category] = slug.split(":");
    return category;
  };


  if (loading) {
    return <div className="flex justify-center p-8">Loading...</div>;
  }

  return (
    <div className="max-w-6xl mx-auto p-6 text-gray-500">
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

      <CreateEditPermissionModal
        isOpen={showCreateForm}
        editingPermission={editingPermission}
        formData={formData}
        onClose={resetForm}
        onSubmit={handleSubmit}
        onNameChange={handleNameChange}
        onFormDataChange={handleFormDataChange}
      />

      <PermissionsTable
        permissions={permissions}
        loading={loading}
        onEdit={handleEdit}
        onDelete={handleDelete}
        onCreateFirst={() => setShowCreateForm(true)}
        getPermissionCategory={getPermissionCategory}
      />
    </div>
  );
}

/** Permissions CRUD, grouped by category. */
export default function PermissionsManagement() {
  return (
    <IslandProviders>
      <PermissionsManagementScreen />
    </IslandProviders>
  );
}
