import { useState } from "react";
import { useSearchParams } from "react-router";
import { keepPreviousData, useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { toast } from "react-hot-toast";
import { describeError, getErrorMessage, usePermissions } from "@rephi/shared-components";
import Layout from "~/components/bedrock/Layout";
import { ErrorAlert, Pagination } from "~/components/commons";
import { NEW_RECORD_PARAM } from "~/config/routes";
import { ADMIN_PAGE_SIZE, adminKeys, rolesApi } from "~/modules/api/admin";
import type { Role } from "~/types/admin.types";
import SlugRecordModal, { type SlugRecordValues } from "../shared/SlugRecordModal";
import { roleSlugFromName, validateRoleSlug } from "../shared/slugs";
import RolePermissionsModal from "./RolePermissionsModal";
import RolesTable from "./RolesTable";

type Editing = { mode: "create" } | { mode: "edit"; role: Role } | null;

export default function RolesManagement() {
  const queryClient = useQueryClient();
  const { can } = usePermissions();
  const [page, setPage] = useState(1);
  const [editing, setEditing] = useState<Editing>(null);
  const [searchParams, setSearchParams] = useSearchParams();
  const createFromUrl = searchParams.get(NEW_RECORD_PARAM) === "1" && can("roles:create");
  const form: Editing = editing ?? (createFromUrl ? { mode: "create" } : null);
  const [selectedRole, setSelectedRole] = useState<Role | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);

  const rolesQuery = useQuery({
    queryKey: adminKeys.rolesPage(page),
    queryFn: () => rolesApi.list({ page, page_size: ADMIN_PAGE_SIZE }),
    placeholderData: keepPreviousData,
  });

  const invalidate = () => queryClient.invalidateQueries({ queryKey: adminKeys.roles });

  const save = useMutation({
    mutationFn: (values: SlugRecordValues) =>
      form?.mode === "edit" ? rolesApi.update(form.role.id, values) : rolesApi.create(values),
    onSuccess: (role) => {
      toast.success(form?.mode === "edit" ? `Role "${role.name}" updated` : `Role "${role.name}" created`);
      closeForm();
      invalidate();
    },
  });

  const remove = useMutation({
    mutationFn: (role: Role) => rolesApi.delete(role.id),
    onSuccess: (_, role) => {
      toast.success(`Role "${role.name}" deleted`);
      if (rolesQuery.data?.data.length === 1 && page > 1) setPage(page - 1);
      invalidate();
    },
    onError: (error) => setActionError(getErrorMessage(error, "Error deleting role")),
  });

  const openForm = (next: Editing) => {
    save.reset();
    setEditing(next);
  };

  const closeForm = () => {
    setEditing(null);
    // Otherwise a reload or Back reopens the form.
    if (searchParams.has(NEW_RECORD_PARAM)) {
      setSearchParams(
        (params) => {
          params.delete(NEW_RECORD_PARAM);
          return params;
        },
        { replace: true }
      );
    }
  };

  const handleDelete = (role: Role) => {
    if (!confirm(`Delete the role "${role.name}"?`)) return;
    setActionError(null);
    remove.mutate(role);
  };

  const saveError = save.error ? describeError(save.error) : null;

  return (
    <Layout title="Roles Management">
      <div className="max-w-6xl mx-auto p-6 text-gray-500">
        <div className="flex justify-between items-center mb-6">
          <h1 className="text-3xl font-bold">Roles Management</h1>
          {can("roles:create") && (
            <button
              type="button"
              onClick={() => openForm({ mode: "create" })}
              className="bg-blue-600 text-white px-4 py-2 rounded hover:bg-blue-700"
            >
              Create Role
            </button>
          )}
        </div>

        <ErrorAlert message={actionError} onDismiss={() => setActionError(null)} />

        {rolesQuery.isPending ? (
          <div className="flex justify-center p-8">Loading...</div>
        ) : rolesQuery.isError ? (
          <ErrorAlert message={getErrorMessage(rolesQuery.error, "Error loading roles")} />
        ) : (
          <>
            <RolesTable
              roles={rolesQuery.data.data}
              canEdit={can("roles:edit")}
              canDelete={can("roles:delete")}
              onViewPermissions={setSelectedRole}
              onEdit={(role) => openForm({ mode: "edit", role })}
              onDelete={handleDelete}
            />
            <Pagination
              meta={rolesQuery.data.meta}
              onPageChange={setPage}
              busy={rolesQuery.isPlaceholderData}
              label="Roles pages"
            />
          </>
        )}

        {form && (
          <SlugRecordModal
            key={form.mode === "edit" ? form.role.id : "new"}
            noun="Role"
            editing={
              form.mode === "edit"
                ? { ...form.role, description: form.role.description ?? "" }
                : null
            }
            onClose={closeForm}
            onSubmit={(values) => save.mutate(values)}
            submitting={save.isPending}
            serverFieldErrors={saveError?.fieldErrors ?? {}}
            serverError={saveError && Object.keys(saveError.fieldErrors).length === 0 ? saveError.message : null}
            validateSlug={validateRoleSlug}
            slugFromName={roleSlugFromName}
            slugPlaceholder="e.g., editor"
            slugHint="Lowercase letters and digits, separated by - or _"
          />
        )}

        {selectedRole && (
          <RolePermissionsModal
            key={selectedRole.id}
            role={selectedRole}
            onClose={() => setSelectedRole(null)}
          />
        )}
      </div>
    </Layout>
  );
}
