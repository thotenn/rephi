import { Modal } from "~/components/commons";
import type { Role } from "~/types/admin.types";

interface CreateEditRoleModalProps {
  isOpen: boolean;
  editingRole: Role | null;
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

export default function CreateEditRoleModal({
  isOpen,
  editingRole,
  formData,
  onClose,
  onSubmit,
  onNameChange,
  onFormDataChange,
}: CreateEditRoleModalProps) {
  return (
    <Modal
      isOpen={isOpen}
      onClose={onClose}
      title={editingRole ? "Edit Role" : "Create Role"}
    >
      <form onSubmit={onSubmit}>
        <div className="mb-4">
          <label
            htmlFor="role-name"
            className="block text-sm font-medium mb-2 text-gray-500"
          >
            Name
          </label>
          <input
            id="role-name"
            type="text"
            value={formData.name}
            onChange={(e) => onNameChange(e.target.value)}
            className="w-full border rounded px-3 py-2"
            required
          />
        </div>
        <div className="mb-4">
          <label
            htmlFor="role-slug"
            className="block text-sm font-medium mb-2 text-gray-500"
          >
            Slug
          </label>
          <input
            id="role-slug"
            type="text"
            value={formData.slug}
            onChange={(e) => onFormDataChange("slug", e.target.value)}
            className="w-full border rounded px-3 py-2"
            required
          />
        </div>
        <div className="mb-4">
          <label
            htmlFor="role-description"
            className="block text-sm font-medium mb-2 text-gray-500"
          >
            Description
          </label>
          <textarea
            id="role-description"
            value={formData.description}
            onChange={(e) => onFormDataChange("description", e.target.value)}
            className="w-full border rounded px-3 py-2"
            rows={3}
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
            {editingRole ? "Update" : "Create"}
          </button>
        </div>
      </form>
    </Modal>
  );
}