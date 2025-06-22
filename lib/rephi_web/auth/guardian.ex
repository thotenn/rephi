defmodule RephiWeb.Auth.Guardian do
  @moduledoc """
  Guardian implementation for JWT token management with authorization support.

  This module extends the basic Guardian functionality to include user roles
  and permissions in JWT tokens, enabling client-side authorization checks
  and reducing server round-trips for permission verification.

  ## Token Claims

  In addition to standard JWT claims, tokens include:
  - `roles` - Array of role slugs the user has assigned
  - `permissions` - Array of all permission slugs the user has (direct + via roles)

  ## Example Token Claims

      {
        "sub": "123",
        "exp": 1640995200,
        "roles": ["manager", "user"],
        "permissions": ["users:view", "users:create", "roles:view"]
      }

  ## Usage

      # Generate token with enhanced claims
      {:ok, token, claims} = Guardian.encode_and_sign(user)

      # Extract user from token
      {:ok, user} = Guardian.resource_from_token(token)

  """
  use Guardian, otp_app: :rephi

  alias Rephi.{Accounts, Authorization}

  def subject_for_token(user, _claims) do
    {:ok, to_string(user.id)}
  end

  def resource_from_claims(%{"sub" => id}) do
    case Accounts.get_user(id) do
      nil -> {:error, :resource_not_found}
      user -> {:ok, user}
    end
  end

  @doc """
  Builds additional claims to include roles and permissions in the JWT token.

  This function is automatically called by Guardian when generating tokens.
  It enriches the standard JWT claims with the user's current roles and
  permissions, enabling client-side authorization checks.

  ## Parameters

    * `claims` - The base JWT claims map
    * `resource` - The user struct to generate claims for
    * `_opts` - Additional options (unused)

  ## Returns

    * `{:ok, enhanced_claims}` - Claims map with roles and permissions added

  ## Example

      # Before: %{"sub" => "123", "exp" => 1640995200}
      # After:  %{
      #   "sub" => "123", 
      #   "exp" => 1640995200,
      #   "roles" => ["admin"],
      #   "permissions" => ["users:view", "users:create", "roles:manage"]
      # }

  """
  def build_claims(claims, resource, _opts) do
    roles = Authorization.get_user_roles(resource)
    permissions = Authorization.get_user_permissions(resource)

    claims =
      claims
      |> Map.put("roles", Enum.map(roles, & &1.slug))
      |> Map.put("permissions", Enum.map(permissions, & &1.slug))

    {:ok, claims}
  end
end
