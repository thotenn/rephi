defmodule RephiWeb.Auth.Guardian do
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
