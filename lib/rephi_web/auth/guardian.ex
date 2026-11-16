defmodule RephiWeb.Auth.Guardian do
  @moduledoc """
  Guardian implementation for JWT token management with authorization support.

  Tokens are short-lived access tokens (`ttl` in the configuration, 24 hours
  by default, `TOKEN_TTL_SECONDS` at runtime). There is no refresh token: when
  a token expires or is revoked the client logs in again.

  ## Token Claims

  In addition to standard JWT claims, tokens include:
  - `ver` - The `token_version` of the user when the token was issued
  - `roles` - Array of the slugs of the roles assigned to the user (not the
    inherited ones)
  - `permissions` - Array of the slugs of every effective permission (direct,
    through roles, inherited)

  `roles` and `permissions` are a convenience for clients. The server never
  trusts them: every request is authorized against the database.

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

  ## What makes a token valid

    * the signature, with the configured `secret_key`;
    * `exp` is present and in the future, and `iss` is the configured issuer
      (`verify_claims/2`);
    * `sub` is the id of an existing user and `ver` equals that user's current
      `token_version` (`resource_from_claims/1`). Changing the password,
      logging out (`Rephi.Accounts.revoke_tokens/1`) or deleting the user
      therefore invalidates every token issued before;
    * callers additionally require `typ` to be `"access"`
      (`RephiWeb.Auth.Pipeline`, `RephiWeb.UserSocket`).

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
  Loads the user a token belongs to.

  Fails when the user no longer exists, when the token was issued before the
  user's tokens were last revoked, or when the claims do not identify a user
  at all. Malformed claims are an error, never an exception.
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
  Rejects tokens that never expire or that do not say who issued them.

  Guardian only validates `exp` and `iss` when they are present; this makes
  them mandatory.
  """
  def verify_claims(%{"exp" => exp, "iss" => iss} = claims, _opts)
      when is_integer(exp) and is_binary(iss) do
    {:ok, claims}
  end

  def verify_claims(_claims, _opts), do: {:error, :invalid_claims}

  @doc """
  Adds the token version, the assigned role slugs and the effective
  permission slugs to the claims of a new token.

  Called by Guardian when a token is signed. Pass the user's
  `Rephi.Authorization.Access` as the `:access` option of
  `encode_and_sign/3` when it is already loaded; otherwise it is loaded here
  (one query).
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
