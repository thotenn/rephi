import { useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { fetchMe, getErrorMessage, usePermissions, type RoleLink } from "@rephi/shared-components";
import { ErrorAlert } from "~/components/commons";
import { adminKeys, rolesApi } from "~/modules/api/admin";
import type { Role } from "~/types/admin.types";

interface RoleParentsSectionProps {
  role: Role;
}

function LinkedRole({ link, children }: { link: RoleLink; children?: React.ReactNode }) {
  return (
    <div className="flex justify-between items-center p-2 bg-gray-50 rounded" data-testid={`role-link-${link.slug}`}>
      <div>
        <span className="font-medium text-gray-700">{link.name}</span>
        <span className="text-sm text-gray-500 ml-2">({link.slug})</span>
        {link.system_link && (
          <span
            className="ml-2 inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-gray-200 text-gray-700"
            title="Part of the default hierarchy: it cannot be removed"
          >
            Default
          </span>
        )}
      </div>
      {children}
    </div>
  );
}

/**
 * The hierarchy around a role: the roles it inherits from (its parents, which
 * `roles:edit` can add and remove) and the roles that inherit from it (read
 * only). The server decides what is allowed: a cycle, a link of the default
 * hierarchy or the last admins' path to the admin role are refused, and its
 * message is shown as is.
 */
export default function RoleParentsSection({ role }: RoleParentsSectionProps) {
  const queryClient = useQueryClient();
  const { can } = usePermissions();
  const canEdit = can("roles:edit");
  const [selected, setSelected] = useState("");
  const [error, setError] = useState<string | null>(null);

  const parents = useQuery({ queryKey: adminKeys.roleParents(role.id), queryFn: () => rolesApi.parents(role.id) });
  const children = useQuery({ queryKey: adminKeys.roleChildren(role.id), queryFn: () => rolesApi.children(role.id) });
  const allRoles = useQuery({ queryKey: adminKeys.allRoles, queryFn: rolesApi.all, enabled: canEdit });

  const afterChange = () => {
    setError(null);
    setSelected("");
    // Both ends of the link and every inherited permission may have changed.
    queryClient.invalidateQueries({ queryKey: adminKeys.hierarchy });
    queryClient.invalidateQueries({ queryKey: adminKeys.role(role.id) });
    // The signed-in user may hold this role: refresh their permissions.
    fetchMe().catch(() => {});
  };

  const add = useMutation({
    mutationFn: (parentId: number) => rolesApi.addParent(role.id, parentId),
    onSuccess: afterChange,
    onError: (err) => setError(getErrorMessage(err, "Error adding the parent role")),
  });

  const remove = useMutation({
    mutationFn: (parentId: number) => rolesApi.removeParent(role.id, parentId),
    onSuccess: afterChange,
    onError: (err) => setError(getErrorMessage(err, "Error removing the parent role")),
  });

  const busy = add.isPending || remove.isPending;
  const parentIds = new Set((parents.data ?? []).map((parent) => parent.id));
  const candidates = (allRoles.data ?? []).filter((candidate) => candidate.id !== role.id && !parentIds.has(candidate.id));

  return (
    <section className="mb-6 pb-6 border-b" data-testid="role-hierarchy">
      <ErrorAlert message={error} onDismiss={() => setError(null)} />
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div>
          <h3 className="text-lg font-semibold mb-1 text-gray-500">Parent Roles</h3>
          <p className="text-xs text-gray-500 mb-3">{role.name} inherits every permission of these roles.</p>
          <div className="space-y-2" data-testid="parent-roles">
            {parents.isPending && <p className="text-gray-500">Loading...</p>}
            {parents.isError && <ErrorAlert message={getErrorMessage(parents.error, "Error loading the parent roles")} />}
            {parents.data?.map((parent) => (
              <LinkedRole key={parent.id} link={parent}>
                {canEdit && (
                  <button
                    type="button"
                    onClick={() => remove.mutate(parent.id)}
                    disabled={busy}
                    className="text-red-600 hover:text-red-800 text-sm disabled:opacity-50"
                  >
                    Remove
                  </button>
                )}
              </LinkedRole>
            ))}
            {parents.isSuccess && parents.data.length === 0 && <p className="text-gray-500">No parent roles</p>}
          </div>

          {canEdit && (
            <form
              className="mt-3 flex gap-2"
              onSubmit={(event) => {
                event.preventDefault();
                if (selected) add.mutate(Number(selected));
              }}
            >
              <label htmlFor={`add-parent-${role.id}`} className="sr-only">
                Parent role to add
              </label>
              <select
                id={`add-parent-${role.id}`}
                value={selected}
                onChange={(event) => setSelected(event.target.value)}
                className="flex-1 border rounded px-2 py-1 text-gray-900"
                data-testid="add-parent-select"
              >
                <option value="">Add a parent role...</option>
                {candidates.map((candidate) => (
                  <option key={candidate.id} value={candidate.id}>
                    {candidate.name} ({candidate.slug})
                  </option>
                ))}
              </select>
              <button
                type="submit"
                disabled={!selected || busy}
                className="bg-blue-600 text-white px-3 py-1 rounded hover:bg-blue-700 disabled:opacity-50"
              >
                Add
              </button>
            </form>
          )}
        </div>

        <div>
          <h3 className="text-lg font-semibold mb-1 text-gray-500">Child Roles</h3>
          <p className="text-xs text-gray-500 mb-3">These roles inherit every permission of {role.name}.</p>
          <div className="space-y-2" data-testid="child-roles">
            {children.isPending && <p className="text-gray-500">Loading...</p>}
            {children.isError && <ErrorAlert message={getErrorMessage(children.error, "Error loading the child roles")} />}
            {children.data?.map((child) => <LinkedRole key={child.id} link={child} />)}
            {children.isSuccess && children.data.length === 0 && <p className="text-gray-500">No child roles</p>}
          </div>
        </div>
      </div>
    </section>
  );
}
