import { Modal } from "~/components/commons";
import type { Permission } from "~/types/admin.types";

interface CreateEditPermissionModalProps {
  isOpen: boolean;
  editingPermission: Permission | null;
  formData: {
    name: string;
    slug: string;
    description: string;
  };
  onClose: () => void;
  onSubmit: (e: React.FormEvent) => void;
  onNameChange: (name: string) => void;
  onFormDataChange: (field: string, value: string) => void;
}

export default function CreateEditPermissionModal({
  isOpen,
  editingPermission,
  formData,
  onClose,
  onSubmit,
  onNameChange,
  onFormDataChange,
}: CreateEditPermissionModalProps) {
  return (
    <Modal
      isOpen={isOpen}
      onClose={onClose}
      title={editingPermission ? "Edit Permission" : "Create Permission"}
    >
      <form onSubmit={onSubmit}>
        <div className="mb-4">
          <label
            htmlFor="permission-name"
            className="block text-sm font-medium mb-2 text-gray-500"
          >
            Name
          </label>
          <input
            id="permission-name"
            type="text"
            value={formData.name}
            onChange={(e) => onNameChange(e.target.value)}
            className="w-full border rounded px-3 py-2"
            placeholder="e.g., Edit Users"
            required
          />
        </div>
        <div className="mb-4">
          <label
            htmlFor="permission-slug"
            className="block text-sm font-medium mb-2 text-gray-500"
          >
            Slug
          </label>
          <input
            id="permission-slug"
            type="text"
            value={formData.slug}
            onChange={(e) => onFormDataChange("slug", e.target.value)}
            className="w-full border rounded px-3 py-2"
            placeholder="e.g., users:edit"
            required
          />
          <p className="text-sm text-gray-500 mt-1">
            Use format: category:action (e.g., users:edit, roles:create)
          </p>
        </div>
        <div className="mb-4">
          <label
            htmlFor="permission-description"
            className="block text-sm font-medium mb-2 text-gray-500"
          >
            Description
          </label>
          <textarea
            id="permission-description"
            value={formData.description}
            onChange={(e) => onFormDataChange("description", e.target.value)}
            className="w-full border rounded px-3 py-2"
            rows={3}
            placeholder="Describe what this permission allows"
          />
        </div>
        <div className="flex justify-end gap-2">
          <button
            type="button"
            onClick={onClose}
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
    </Modal>
  );
}