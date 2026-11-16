defmodule RephiWeb.Auth.Guardian do
  @moduledoc """
  Guardian implementation for JWT token management with authorization support.

  Access tokens live `ttl` (24 hours by default); there is no refresh token.

  ## Token Claims

  In addition to standard JWT claims, tokens include:
  - `ver` - The `token_version` of the user when the token was issued
  - `roles` - Array of the slugs of the roles assigned to the user (not the
    inherited ones)
  - `permissions` - Array of the slugs of every effective permission (direct,
    through roles, inherited)

  The server never trusts `roles` and `permissions`: every request is
  authorized against the database.

  ## Example Token Claims

      {
        "sub": "123",
        "typ": "access",
        "iss": "rephi",
        "exp": 1640995200,
        "ver": 0,
        "roles": ["manager", "user"],
        "permissions": ["users:view", "users:create", "roles:view"]
      }

  A token is valid with a good signature, a future `exp`, the configured `iss`
  and a `ver` equal to its user's current `token_version`; callers also require
  `typ` to be `"access"`.

  ## Usage

      # Generate token with enhanced claims
      {:ok, token, claims} = Guardian.encode_and_sign(user)

      # Extract user from token
      {:ok, user, claims} = Guardian.resource_from_token(token, %{"typ" => "access"})

  """
  use Guardian, otp_app: :rephi

  alias Rephi.{Accounts, Authorization}
  alias Rephi.Accounts.User

  def subject_for_token(%User{id: id}, _claims) do
    {:ok, to_string(id)}
  end

  @doc """
  Loads the user a token belongs to. Fails, never raises, when the user is gone,
  `ver` is outdated or the claims are malformed.
  """
  def resource_from_claims(%{"sub" => id, "ver" => version}) when is_integer(version) do
    case Accounts.get_user(id) do
      %User{token_version: ^version} = user -> {:ok, user}
      %User{} -> {:error, :token_revoked}
      nil -> {:error, :resource_not_found}
    end
  end

  def resource_from_claims(_claims), do: {:error, :invalid_claims}

  @doc """
  Rejects tokens without `exp` or `iss` (Guardian only checks them when present).
  """
  def verify_claims(%{"exp" => exp, "iss" => iss} = claims, _opts)
      when is_integer(exp) and is_binary(iss) do
    {:ok, claims}
  end

  def verify_claims(_claims, _opts), do: {:error, :invalid_claims}

  @doc """
  Adds `ver`, the assigned role slugs and the effective permission slugs. Pass
  `access:` to `encode_and_sign/3` when the user's `Access` is already loaded.
  """
  def build_claims(claims, %User{} = resource, opts) do
    access = Keyword.get(opts, :access) || Authorization.load_access(resource)

    claims =
      claims
      |> Map.put("ver", resource.token_version)
      |> Map.put("roles", Enum.map(access.roles, & &1.slug))
      |> Map.put("permissions", Enum.map(access.permissions, & &1.slug))

    {:ok, claims}
  end
end
