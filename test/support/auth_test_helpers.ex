defmodule Rephi.AuthTestHelpers do
  @moduledoc """
  Helper functions for authentication in tests.
  """

  alias Rephi.Accounts
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
  Generates a valid user attributes map for testing.
  """
  def valid_user_attrs(overrides \\ %{}) do
    Map.merge(
      %{
        "email" => "test#{System.unique_integer()}@example.com",
        "password" => "password123"
      },
      overrides
    )
  end

  @doc """
  Generates invalid user attributes for testing validation errors.
  """
  def invalid_user_attrs do
    %{
      "email" => "invalid-email",
      "password" => "short"
    }
  end
end