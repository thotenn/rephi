import { useState } from "react";
import { keepPreviousData, useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { toast } from "react-hot-toast";
import { describeError, getErrorMessage, usePermissions } from "@rephi/shared-components";
import Layout from "~/components/bedrock/Layout";
import { ErrorAlert, Pagination } from "~/components/commons";
import { ADMIN_PAGE_SIZE, adminKeys, permissionsApi } from "~/modules/api/admin";
import type { Permission } from "~/types/admin.types";
import SlugRecordModal, { type SlugRecordValues } from "../shared/SlugRecordModal";
import { permissionSlugFromName, validatePermissionSlug } from "../shared/slugs";
import PermissionsTable from "./PermissionsTable";

type Editing = { mode: "create" } | { mode: "edit"; permission: Permission } | null;

export default function PermissionsManagement() {
  const queryClient = useQueryClient();
  const { can } = usePermissions();
  const [page, setPage] = useState(1);
  const [editing, setEditing] = useState<Editing>(null);
  const [actionError, setActionError] = useState<string | null>(null);

  const permissionsQuery = useQuery({
    queryKey: adminKeys.permissionsPage(page),
    queryFn: () => permissionsApi.list({ page, page_size: ADMIN_PAGE_SIZE }),
    placeholderData: keepPreviousData,
  });

  const invalidate = () => queryClient.invalidateQueries({ queryKey: adminKeys.permissions });

  const save = useMutation({
    mutationFn: (values: SlugRecordValues) =>
      editing?.mode === "edit"
        ? permissionsApi.update(editing.permission.id, values)
        : permissionsApi.create(values),
    onSuccess: (permission) => {
      toast.success(editing?.mode === "edit" ? `Permission "${permission.name}" updated` : `Permission "${permission.name}" created`);
      setEditing(null);
      invalidate();
    },
  });

  const remove = useMutation({
    mutationFn: (permission: Permission) => permissionsApi.delete(permission.id),
    onSuccess: (_, permission) => {
      toast.success(`Permission "${permission.name}" deleted`);
      if (permissionsQuery.data?.data.length === 1 && page > 1) setPage(page - 1);
      invalidate();
    },
    onError: (error) => setActionError(getErrorMessage(error, "Error deleting permission")),
  });

  const openForm = (next: Editing) => {
    save.reset();
    setEditing(next);
  };

  const handleDelete = (permission: Permission) => {
    if (!confirm(`Delete the permission "${permission.name}"?`)) return;
    setActionError(null);
    remove.mutate(permission);
  };

  const saveError = save.error ? describeError(save.error) : null;

  return (
    <Layout title="Permission Management">
      <div className="max-w-6xl mx-auto p-6 text-gray-500">
        <div className="flex justify-between items-center mb-6">
          <h1 className="text-3xl font-bold">Permissions Management</h1>
          {can("permissions:create") && (
            <button
              type="button"
              onClick={() => openForm({ mode: "create" })}
              className="bg-blue-600 text-white px-4 py-2 rounded hover:bg-blue-700"
            >
              Create Permission
            </button>
          )}
        </div>

        <ErrorAlert message={actionError} onDismiss={() => setActionError(null)} />

        {permissionsQuery.isPending ? (
          <div className="flex justify-center p-8">Loading...</div>
        ) : permissionsQuery.isError ? (
          <ErrorAlert message={getErrorMessage(permissionsQuery.error, "Error loading permissions")} />
        ) : (
          <>
            <PermissionsTable
              permissions={permissionsQuery.data.data}
              canEdit={can("permissions:edit")}
              canDelete={can("permissions:delete")}
              onEdit={(permission) => openForm({ mode: "edit", permission })}
              onDelete={handleDelete}
            />
            <Pagination
              meta={permissionsQuery.data.meta}
              onPageChange={setPage}
              busy={permissionsQuery.isPlaceholderData}
              label="Permissions pages"
            />
          </>
        )}

        {editing && (
          <SlugRecordModal
            key={editing.mode === "edit" ? editing.permission.id : "new"}
            noun="Permission"
            editing={
              editing.mode === "edit"
                ? { ...editing.permission, description: editing.permission.description ?? "" }
                : null
            }
            onClose={() => setEditing(null)}
            onSubmit={(values) => save.mutate(values)}
            submitting={save.isPending}
            serverFieldErrors={saveError?.fieldErrors ?? {}}
            serverError={saveError && Object.keys(saveError.fieldErrors).length === 0 ? saveError.message : null}
            validateSlug={validatePermissionSlug}
            slugFromName={permissionSlugFromName}
            slugPlaceholder="e.g., users:edit"
            slugHint="Use format: category:action (e.g., users:edit, roles:create)"
          />
        )}
      </div>
    </Layout>
  );
}
