# Script for populating the database with default roles and permissions
alias Rephi.{Repo, Authorization}
alias Rephi.Authorization.{Role, Permission}

# Create default roles
{:ok, admin_role} = Authorization.create_role(%{
  name: "Administrator",
  slug: "admin",
  description: "Full system access"
})

{:ok, manager_role} = Authorization.create_role(%{
  name: "Manager",
  slug: "manager",
  description: "Management level access"
})

{:ok, user_role} = Authorization.create_role(%{
  name: "User",
  slug: "user",
  description: "Basic user access"
})

# Set up role hierarchy
Authorization.assign_parent_role(admin_role, manager_role)
Authorization.assign_parent_role(manager_role, user_role)

# Create permissions for user management
user_permissions = [
  %{name: "View Users", slug: "users:view", description: "View user profiles and listings"},
  %{name: "Create Users", slug: "users:create", description: "Create new user accounts"},
  %{name: "Edit Users", slug: "users:edit", description: "Edit user information"},
  %{name: "Delete Users", slug: "users:delete", description: "Delete user accounts"}
]

user_perms = Enum.map(user_permissions, fn attrs ->
  {:ok, perm} = Authorization.create_permission(attrs)
  perm
end)

# Create permissions for role management
role_permissions = [
  %{name: "View Roles", slug: "roles:view", description: "View roles and their permissions"},
  %{name: "Create Roles", slug: "roles:create", description: "Create new roles"},
  %{name: "Edit Roles", slug: "roles:edit", description: "Edit role information"},
  %{name: "Delete Roles", slug: "roles:delete", description: "Delete roles"},
  %{name: "Assign Roles", slug: "roles:assign", description: "Assign roles to users"}
]

role_perms = Enum.map(role_permissions, fn attrs ->
  {:ok, perm} = Authorization.create_permission(attrs)
  perm
end)

# Create permissions for permission management
permission_permissions = [
  %{name: "View Permissions", slug: "permissions:view", description: "View permissions"},
  %{name: "Create Permissions", slug: "permissions:create", description: "Create new permissions"},
  %{name: "Edit Permissions", slug: "permissions:edit", description: "Edit permission information"},
  %{name: "Delete Permissions", slug: "permissions:delete", description: "Delete permissions"},
  %{name: "Assign Permissions", slug: "permissions:assign", description: "Assign permissions to roles or users"}
]

perm_perms = Enum.map(permission_permissions, fn attrs ->
  {:ok, perm} = Authorization.create_permission(attrs)
  perm
end)

# Create system permissions
system_permissions = [
  %{name: "Access System Settings", slug: "system:settings", description: "Access system configuration"},
  %{name: "View System Logs", slug: "system:logs", description: "View system logs and audit trails"},
  %{name: "Manage System", slug: "system:manage", description: "Perform system maintenance"}
]

system_perms = Enum.map(system_permissions, fn attrs ->
  {:ok, perm} = Authorization.create_permission(attrs)
  perm
end)

# Assign permissions to roles

# Basic user permissions
[users_view] = Enum.filter(user_perms, & &1.slug == "users:view")
Authorization.assign_permission_to_role(user_role, users_view)

# Manager permissions (inherits from user)
manager_specific_perms = Enum.filter(user_perms, & &1.slug in ["users:create", "users:edit"])
Enum.each(manager_specific_perms, &Authorization.assign_permission_to_role(manager_role, &1))

roles_view = Enum.find(role_perms, & &1.slug == "roles:view")
Authorization.assign_permission_to_role(manager_role, roles_view)

# Admin permissions (inherits from manager and user)
# Admin gets all remaining permissions
all_perms = user_perms ++ role_perms ++ perm_perms ++ system_perms
Enum.each(all_perms, &Authorization.assign_permission_to_role(admin_role, &1))

IO.puts("Authorization seed data created successfully!")
IO.puts("\nCreated roles:")
IO.puts("  - admin (inherits from: manager)")
IO.puts("  - manager (inherits from: user)")
IO.puts("  - user")
IO.puts("\nCreated #{length(all_perms)} permissions across:")
IO.puts("  - User management")
IO.puts("  - Role management")
IO.puts("  - Permission management")
IO.puts("  - System management")