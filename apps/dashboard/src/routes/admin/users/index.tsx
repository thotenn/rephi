import { useState, useEffect } from "react";
import Layout from "~/components/bedrock/Layout";
import { usersApi, rolesApi } from "~/modules/api/admin";
import type { UserWithAuth, Role } from "~/types/admin.types";
import UsersTable from "./UsersTable";
import UserRolesModal from "./UserRolesModal";

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
    <Layout title="User Management">
      <div className="max-w-7xl mx-auto p-6">

        {error && (
          <div className="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded mb-4">
            {error}
          </div>
        )}

        <UsersTable
          users={users}
          loading={loading}
          onViewUserRoles={handleViewUserRoles}
          formatDate={formatDate}
          getRoleColor={getRoleColor}
        />

        <UserRolesModal
          selectedUser={selectedUser}
          userRoles={userRoles}
          roles={roles}
          onClose={() => setSelectedUser(null)}
          onAssignRole={handleAssignRole}
          onRemoveRole={handleRemoveRole}
          getRoleColor={getRoleColor}
        />
      </div>
    </Layout>
  );
}
