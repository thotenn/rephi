defmodule Rephi.AuthTestHelpers do
  @moduledoc """
  Helper functions for authentication in tests.
  """

  alias Rephi.Accounts
  alias Rephi.Authorization
  alias RephiWeb.Auth.Guardian

  @doc """
  Creates a user and returns the user struct.
  """
  def create_user(attrs \\ %{}) do
    default_attrs = %{
      email: "user#{System.unique_integer()}@example.com",
      password: "password123"
    }

    attrs = Map.merge(default_attrs, attrs)
    {:ok, user} = Accounts.create_user(attrs)
    user
  end

  @doc """
  Creates a user and generates a JWT token for them.
  Returns {user, token}.
  """
  def create_user_with_token(attrs \\ %{}) do
    user = create_user(attrs)
    {:ok, token, _claims} = Guardian.encode_and_sign(user)
    {user, token}
  end

  @doc """
  Adds authentication header to a conn.
  """
  def authenticate_conn(conn, token) do
    Plug.Conn.put_req_header(conn, "authorization", "Bearer #{token}")
  end

  @doc """
  Creates a user, generates a token, and authenticates the conn.
  """
  def authenticate_user(conn, attrs \\ %{}) do
    {_user, token} = create_user_with_token(attrs)
    authenticate_conn(conn, token)
  end

  @doc """
  Creates a user holding the given `:roles` and `:permissions` (slugs, created
  if missing) and returns `{user, token}`.
  """
  def create_user_with_token_and(grants, attrs \\ %{}) do
    user = create_user(attrs)

    Enum.each(Keyword.get(grants, :roles, []), &grant_role(user, &1))
    Enum.each(Keyword.get(grants, :permissions, []), &grant_permission(user, &1))

    {:ok, token, _claims} = Guardian.encode_and_sign(user)
    {user, token}
  end

  @doc """
  Assigns the role with the given slug to the user, creating it if needed.
  """
  def grant_role(user, slug) do
    role = Authorization.get_role_by_slug(slug) || create_role(%{slug: slug})
    {:ok, _user_role} = Authorization.assign_role_to_user(user, role)
    role
  end

  @doc """
  Assigns the permission with the given slug directly to the user, creating it
  if needed.
  """
  def grant_permission(user, slug) do
    permission = Authorization.get_permission_by_slug(slug) || create_permission(%{slug: slug})
    {:ok, _user_permission} = Authorization.assign_permission_to_user(user, permission)
    permission
  end

  @doc """
  Creates a role. `name` and `slug` get unique defaults.
  """
  def create_role(attrs \\ %{}) do
    slug = "role_#{System.unique_integer([:positive])}"
    {:ok, role} = Authorization.create_role(Map.merge(%{name: slug, slug: slug}, attrs))
    role
  end

  @doc """
  Creates a permission. `name` and `slug` get unique defaults.
  """
  def create_permission(attrs \\ %{}) do
    slug = "things:action_#{System.unique_integer([:positive])}"

    {:ok, permission} =
      Authorization.create_permission(Map.merge(%{name: slug, slug: slug}, attrs))

    permission
  end

  @doc """
  Signs `claims` as an HS512 JWT, bypassing Guardian, to build tokens it never
  issues. `claims` are merged over a regular access token's (`nil` removes one);
  `opts[:secret]` overrides the key.
  """
  def forge_token(user, claims \\ %{}, opts \\ []) do
    now = System.system_time(:second)

    base = %{
      "sub" => user && to_string(user.id),
      "ver" => user && user.token_version,
      "typ" => "access",
      "iss" => "rephi",
      "aud" => "rephi",
      "iat" => now,
      "exp" => now + 3600
    }

    secret =
      Keyword.get_lazy(opts, :secret, fn ->
        Application.fetch_env!(:rephi, Guardian)[:secret_key]
      end)

    claims = base |> Map.merge(claims) |> Map.reject(fn {_key, value} -> is_nil(value) end)

    {_jws, token} =
      secret
      |> JOSE.JWK.from_oct()
      |> JOSE.JWT.sign(%{"alg" => "HS512", "typ" => "JWT"}, claims)
      |> JOSE.JWS.compact()

    token
  end

  @doc """
  Sets an application environment value for the rest of the test and puts the
  previous value back when it finishes. Only for `async: false` tests.
  """
  def put_app_env(app \\ :rephi, key, value) do
    previous = Application.fetch_env(app, key)
    Application.put_env(app, key, value)

    ExUnit.Callbacks.on_exit(fn ->
      case previous do
        {:ok, old} -> Application.put_env(app, key, old)
        :error -> Application.delete_env(app, key)
      end
    end)
  end

  @doc """
  Ids that can never identify an existing record. Every resource route must
  answer them with a 404, never with a 400 or a 500.
  """
  def invalid_ids, do: ~w(abc 1e3 -1 0 1.5 99999999999999999999)

  @doc """
  Asserts the response is an error in the API envelope and returns its detail.
  """
  def error_detail(conn, status) do
    %{"errors" => %{"detail" => detail} = errors} = Phoenix.ConnTest.json_response(conn, status)

    unless map_size(errors) == 1 and is_binary(detail) do
      raise ExUnit.AssertionError, message: "unexpected error envelope: #{inspect(errors)}"
    end

    detail
  end
end
