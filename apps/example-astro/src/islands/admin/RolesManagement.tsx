import { useState } from "react";
import { keepPreviousData, useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { toast } from "react-hot-toast";
import { describeError, getErrorMessage, usePermissions } from "~/lib/rephi";
import IslandProviders from "~/components/react/IslandProviders";
import { ErrorAlert, Pagination } from "~/components/react";
import { ADMIN_PAGE_SIZE, adminKeys, rolesApi } from "~/lib/api/admin";
import type { Role } from "~/types/admin.types";
import SlugRecordModal, { type SlugRecordValues } from "./shared/SlugRecordModal";
import { roleSlugFromName, validateRoleSlug } from "./shared/slugs";
import RolePermissionsModal from "./RolePermissionsModal";
import RolesTable from "./RolesTable";

type Editing = { mode: "create" } | { mode: "edit"; role: Role } | null;

function RolesManagementScreen() {
  const queryClient = useQueryClient();
  const { can } = usePermissions();
  const [page, setPage] = useState(1);
  const [editing, setEditing] = useState<Editing>(null);
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
      editing?.mode === "edit" ? rolesApi.update(editing.role.id, values) : rolesApi.create(values),
    onSuccess: (role) => {
      toast.success(editing?.mode === "edit" ? `Role "${role.name}" updated` : `Role "${role.name}" created`);
      setEditing(null);
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

  const handleDelete = (role: Role) => {
    if (!confirm(`Delete the role "${role.name}"?`)) return;
    setActionError(null);
    remove.mutate(role);
  };

  const saveError = save.error ? describeError(save.error) : null;

  return (
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

      {editing && (
        <SlugRecordModal
          key={editing.mode === "edit" ? editing.role.id : "new"}
          noun="Role"
          editing={
            editing.mode === "edit"
              ? { ...editing.role, description: editing.role.description ?? "" }
              : null
          }
          onClose={() => setEditing(null)}
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
  );
}

/** Roles list (paginated) with create / edit / delete and the permissions of each role. */
export default function RolesManagement() {
  return (
    <IslandProviders>
      <RolesManagementScreen />
    </IslandProviders>
  );
}
