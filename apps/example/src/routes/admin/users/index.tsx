import { useState } from "react";
import { keepPreviousData, useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { toast } from "react-hot-toast";
import { getErrorMessage, useAuthStore, usePermissions } from "@rephi/shared-components";
import Layout from "~/components/bedrock/Layout";
import { ErrorAlert, Pagination } from "~/components/commons";
import { ADMIN_PAGE_SIZE, adminKeys, usersApi } from "~/modules/api/admin";
import type { UserWithGrants } from "~/types/admin.types";
import EditUserModal from "./EditUserModal";
import UserRolesModal from "./UserRolesModal";
import UsersTable from "./UsersTable";

export default function UsersManagement() {
  const queryClient = useQueryClient();
  const { can } = usePermissions();
  const currentUserId = useAuthStore((state) => state.user?.id);
  const [page, setPage] = useState(1);
  const [rolesFor, setRolesFor] = useState<UserWithGrants | null>(null);
  const [editing, setEditing] = useState<UserWithGrants | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);

  const usersQuery = useQuery({
    queryKey: adminKeys.usersPage(page),
    queryFn: () => usersApi.list({ page, page_size: ADMIN_PAGE_SIZE }),
    placeholderData: keepPreviousData,
  });

  const remove = useMutation({
    mutationFn: (user: UserWithGrants) => usersApi.delete(user.id),
    onSuccess: (_, user) => {
      toast.success(`User ${user.email} deleted`);
      if (usersQuery.data?.data.length === 1 && page > 1) setPage(page - 1);
      queryClient.invalidateQueries({ queryKey: adminKeys.users });
    },
    onError: (error) => setActionError(getErrorMessage(error, "Error deleting user")),
  });

  const handleDelete = (user: UserWithGrants) => {
    if (!confirm(`Delete the user ${user.email}? This cannot be undone.`)) return;
    setActionError(null);
    remove.mutate(user);
  };

  return (
    <Layout title="User Management">
      <div className="max-w-7xl mx-auto p-6">
        <ErrorAlert message={actionError} onDismiss={() => setActionError(null)} />

        {usersQuery.isPending ? (
          <div className="flex justify-center p-8 text-gray-500">Loading...</div>
        ) : usersQuery.isError ? (
          <ErrorAlert message={getErrorMessage(usersQuery.error, "Error loading users")} />
        ) : (
          <>
            <UsersTable
              users={usersQuery.data.data}
              currentUserId={currentUserId}
              canManageRoles={can("roles:assign")}
              canEdit={can("users:edit")}
              canDelete={can("users:delete")}
              onManageRoles={setRolesFor}
              onEdit={setEditing}
              onDelete={handleDelete}
            />
            <Pagination
              meta={usersQuery.data.meta}
              onPageChange={setPage}
              busy={usersQuery.isPlaceholderData}
              label="Users pages"
            />
          </>
        )}

        {rolesFor && (
          <UserRolesModal key={rolesFor.id} user={rolesFor} onClose={() => setRolesFor(null)} />
        )}
        {editing && <EditUserModal key={editing.id} user={editing} onClose={() => setEditing(null)} />}
      </div>
    </Layout>
  );
}
