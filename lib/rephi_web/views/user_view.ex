defmodule RephiWeb.UserView do
  @moduledoc """
  View module for rendering user-related JSON responses.
  Provides consistent user data formatting across the application.
  """

  def render("user.json", %{user: user}) do
    %{
      id: user.id,
      email: user.email
    }
  end

  def render("user_with_token.json", %{user: user, token: token}) do
    %{
      user: render("user.json", %{user: user}),
      token: token
    }
  end

  def render("me.json", %{user: user}) do
    %{
      user: render("user.json", %{user: user})
    }
  end
end
