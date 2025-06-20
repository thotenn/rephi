import { useState, useEffect } from "react";
import { usersApi, rolesApi } from "~/modules/api/admin";
import type { UserWithAuth, Role } from "~/types/admin.types";

export default function UsersManagement() {
  const [users, setUsers] = useState<UserWithAuth[]>([]);
  const [roles, setRoles] = useState<Role[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [selectedUser, setSelectedUser] = useState<UserWithAuth | null>(null);
  const [userRoles, setUserRoles] = useState<Role[]>([]);

  useEffect(() => {
    loadUsers();
    loadRoles();
  }, []);

  const loadUsers = async () => {
    try {
      const response = await usersApi.getAll();
      setUsers(response.data);
    } catch (err) {
      setError("Error loading users");
    } finally {
      setLoading(false);
    }
  };

  const loadRoles = async () => {
    try {
      const response = await rolesApi.getAll();
      setRoles(response.data);
    } catch (err) {
      console.error("Error loading roles:", err);
    }
  };

  const loadUserRoles = async (userId: number) => {
    try {
      const response = await usersApi.getRoles(userId);
      setUserRoles(response.data);
    } catch (err) {
      console.error("Error loading user roles:", err);
    }
  };

  const handleViewUserRoles = async (user: UserWithAuth) => {
    setSelectedUser(user);
    await loadUserRoles(user.id);
  };

  const handleAssignRole = async (roleId: number) => {
    if (!selectedUser) return;
    
    try {
      await usersApi.assignRole(selectedUser.id, roleId);
      await loadUserRoles(selectedUser.id);
      await loadUsers(); // Refresh the main list
    } catch (err) {
      setError("Error assigning role");
    }
  };

  const handleRemoveRole = async (roleId: number) => {
    if (!selectedUser) return;
    
    try {
      await usersApi.removeRole(selectedUser.id, roleId);
      await loadUserRoles(selectedUser.id);
      await loadUsers(); // Refresh the main list
    } catch (err) {
      setError("Error removing role");
    }
  };

  const formatDate = (dateString: string) => {
    return new Date(dateString).toLocaleDateString();
  };

  const getRoleColor = (roleSlug: string) => {
    switch (roleSlug) {
      case "admin":
        return "bg-red-100 text-red-800";
      case "manager":
        return "bg-yellow-100 text-yellow-800";
      case "user":
        return "bg-green-100 text-green-800";
      default:
        return "bg-gray-100 text-gray-800";
    }
  };

  if (loading) {
    return <div className="flex justify-center p-8">Loading...</div>;
  }

  return (
    <div className="max-w-7xl mx-auto p-6">
      <div className="flex justify-between items-center mb-6">
        <h1 className="text-3xl font-bold">User Role Management</h1>
      </div>

      {error && (
        <div className="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded mb-4">
          {error}
        </div>
      )}

      {/* Users Table */}
      <div className="bg-white rounded-lg shadow overflow-hidden">
        <table className="w-full">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                User
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                Current Roles
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                Permissions Count
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                Joined
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                Actions
              </th>
            </tr>
          </thead>
          <tbody className="bg-white divide-y divide-gray-200">
            {(users || []).map((user) => (
              <tr key={user.id}>
                <td className="px-6 py-4 whitespace-nowrap">
                  <div>
                    <div className="font-medium text-gray-900">
                      {user.email}
                    </div>
                    <div className="text-sm text-gray-500">
                      ID: {user.id}
                    </div>
                  </div>
                </td>
                <td className="px-6 py-4">
                  <div className="flex flex-wrap gap-1">
                    {user.roles && user.roles.length > 0 ? (
                      (user.roles || []).map((role) => (
                        <span
                          key={role.id}
                          className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${getRoleColor(role.slug)}`}
                        >
                          {role.name}
                        </span>
                      ))
                    ) : (
                      <span className="text-gray-400 text-sm">No roles</span>
                    )}
                  </div>
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                  {user.permissions ? user.permissions.length : 0}
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                  {formatDate(user.inserted_at)}
                </td>
                <td className="px-6 py-4 whitespace-nowrap">
                  <button
                    onClick={() => handleViewUserRoles(user)}
                    className="text-blue-600 hover:text-blue-800"
                  >
                    Manage Roles
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {users.length === 0 && !loading && (
        <div className="text-center py-12">
          <p className="text-gray-500 text-lg">No users found</p>
        </div>
      )}

      {/* User Roles Management Modal */}
      {selectedUser && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div className="bg-white p-6 rounded-lg w-full max-w-4xl max-h-[80vh] overflow-y-auto">
            <div className="flex justify-between items-center mb-4">
              <h2 className="text-xl font-bold">
                Manage Roles for {selectedUser.email}
              </h2>
              <button
                onClick={() => setSelectedUser(null)}
                className="text-gray-500 hover:text-gray-700"
              >
                ✕
              </button>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              {/* Assigned Roles */}
              <div>
                <h3 className="text-lg font-semibold mb-3">Current Roles</h3>
                <div className="space-y-2 max-h-60 overflow-y-auto">
                  {(userRoles || []).map((role) => (
                    <div
                      key={role.id}
                      className="flex justify-between items-center p-3 bg-green-50 rounded border"
                    >
                      <div>
                        <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${getRoleColor(role.slug)}`}>
                          {role.name}
                        </span>
                        <div className="text-sm text-gray-500 mt-1">
                          {role.description || role.slug}
                        </div>
                      </div>
                      <button
                        onClick={() => handleRemoveRole(role.id)}
                        className="text-red-600 hover:text-red-800 text-sm font-medium"
                        disabled={role.slug === "admin" && userRoles.length === 1}
                        title={role.slug === "admin" && userRoles.length === 1 ? "Cannot remove the last admin role" : "Remove role"}
                      >
                        Remove
                      </button>
                    </div>
                  ))}
                  {(!userRoles || userRoles.length === 0) && (
                    <p className="text-gray-500">No roles assigned</p>
                  )}
                </div>
              </div>

              {/* Available Roles */}
              <div>
                <h3 className="text-lg font-semibold mb-3">Available Roles</h3>
                <div className="space-y-2 max-h-60 overflow-y-auto">
                  {(roles || [])
                    .filter((role) => !(userRoles || []).some((ur) => ur.id === role.id))
                    .map((role) => (
                      <div
                        key={role.id}
                        className="flex justify-between items-center p-3 bg-gray-50 rounded border"
                      >
                        <div>
                          <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${getRoleColor(role.slug)}`}>
                            {role.name}
                          </span>
                          <div className="text-sm text-gray-500 mt-1">
                            {role.description || role.slug}
                          </div>
                        </div>
                        <button
                          onClick={() => handleAssignRole(role.id)}
                          className="text-blue-600 hover:text-blue-800 text-sm font-medium"
                        >
                          Assign
                        </button>
                      </div>
                    ))}
                  {(roles || []).filter((role) => !(userRoles || []).some((ur) => ur.id === role.id)).length === 0 && (
                    <p className="text-gray-500">All roles assigned</p>
                  )}
                </div>
              </div>
            </div>

            {/* User Permissions Preview */}
            {selectedUser.permissions && selectedUser.permissions.length > 0 && (
              <div className="mt-6 pt-6 border-t">
                <h3 className="text-lg font-semibold mb-3">Current Permissions</h3>
                <div className="flex flex-wrap gap-2">
                  {(selectedUser.permissions || []).map((permission) => (
                    <span
                      key={permission.id}
                      className="inline-flex items-center px-2 py-1 rounded text-xs bg-blue-100 text-blue-800"
                    >
                      {permission.slug}
                    </span>
                  ))}
                </div>
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
}