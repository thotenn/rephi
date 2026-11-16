import { useState, type SubmitEvent } from "react";
import type { FieldErrors } from "@rephi/shared-components";
import { ErrorAlert, FieldError, Modal } from "~/components/commons";

export interface SlugRecordValues {
  name: string;
  slug: string;
  description: string;
}

interface SlugRecordModalProps {
  noun: string;
  editing: (SlugRecordValues & { is_system: boolean }) | null;
  onClose: () => void;
  onSubmit: (values: SlugRecordValues) => void;
  submitting: boolean;
  serverFieldErrors: FieldErrors;
  serverError: string | null;
  validateSlug: (slug: string) => string | null;
  slugFromName: (name: string) => string;
  slugPlaceholder: string;
  slugHint: string;
}

export default function SlugRecordModal({
  noun,
  editing,
  onClose,
  onSubmit,
  submitting,
  serverFieldErrors,
  serverError,
  validateSlug,
  slugFromName,
  slugPlaceholder,
  slugHint,
}: SlugRecordModalProps) {
  const [values, setValues] = useState<SlugRecordValues>(
    editing
      ? { name: editing.name, slug: editing.slug, description: editing.description ?? "" }
      : { name: "", slug: "", description: "" }
  );
  const [slugTouched, setSlugTouched] = useState(!!editing);
  const [clientErrors, setClientErrors] = useState<FieldErrors>({});
  const slugLocked = !!editing?.is_system;
  const errors = { ...serverFieldErrors, ...clientErrors };

  const handleSubmit = (event: SubmitEvent<HTMLFormElement>) => {
    event.preventDefault();
    const slugError = slugLocked ? null : validateSlug(values.slug.trim());
    if (slugError) {
      setClientErrors({ slug: [slugError] });
      return;
    }
    setClientErrors({});
    const payload = {
      name: values.name.trim(),
      slug: values.slug.trim(),
      description: values.description.trim(),
    };
    // A system record keeps its slug (the server refuses a change): send it as it is.
    onSubmit(slugLocked ? { ...payload, slug: editing!.slug } : payload);
  };

  return (
    <Modal isOpen onClose={onClose} title={editing ? `Edit ${noun}` : `Create ${noun}`}>
      <form onSubmit={handleSubmit} noValidate>
        <ErrorAlert message={serverError} />
        <div className="mb-4">
          <label htmlFor="record-name" className="block text-sm font-medium mb-2 text-gray-500">
            Name
          </label>
          <input
            id="record-name"
            type="text"
            value={values.name}
            onChange={(e) => {
              const name = e.target.value;
              setValues((v) => ({ ...v, name, slug: slugTouched ? v.slug : slugFromName(name) }));
            }}
            className="w-full border rounded px-3 py-2 text-gray-900"
            required
          />
          <FieldError errors={errors} field="name" />
        </div>
        <div className="mb-4">
          <label htmlFor="record-slug" className="block text-sm font-medium mb-2 text-gray-500">
            Slug
          </label>
          <input
            id="record-slug"
            type="text"
            value={values.slug}
            onChange={(e) => {
              setSlugTouched(true);
              setValues((v) => ({ ...v, slug: e.target.value }));
            }}
            className="w-full border rounded px-3 py-2 text-gray-900 disabled:bg-gray-100"
            placeholder={slugPlaceholder}
            disabled={slugLocked}
            required
          />
          <p className="text-sm text-gray-500 mt-1">
            {slugLocked ? `The slug of a system ${noun.toLowerCase()} cannot change.` : slugHint}
          </p>
          <FieldError errors={errors} field="slug" />
        </div>
        <div className="mb-4">
          <label htmlFor="record-description" className="block text-sm font-medium mb-2 text-gray-500">
            Description
          </label>
          <textarea
            id="record-description"
            value={values.description}
            onChange={(e) => setValues((v) => ({ ...v, description: e.target.value }))}
            className="w-full border rounded px-3 py-2 text-gray-900"
            rows={3}
          />
          <FieldError errors={errors} field="description" />
        </div>
        <div className="flex justify-end gap-2">
          <button type="button" onClick={onClose} className="px-4 py-2 border rounded hover:bg-gray-50">
            Cancel
          </button>
          <button
            type="submit"
            disabled={submitting}
            className="bg-blue-600 text-white px-4 py-2 rounded hover:bg-blue-700 disabled:opacity-50"
          >
            {submitting ? "Saving..." : editing ? "Update" : "Create"}
          </button>
        </div>
      </form>
    </Modal>
  );
}
