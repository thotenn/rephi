defmodule RephiWeb.ErrorJSONTest do
  use ExUnit.Case, async: true

  alias RephiWeb.ErrorJSON

  @status_messages %{
    400 => "Bad Request",
    401 => "Unauthorized",
    403 => "Forbidden",
    404 => "Not Found",
    409 => "Conflict",
    422 => "Unprocessable Content",
    500 => "Internal Server Error"
  }

  for {status, message} <- @status_messages do
    test "renders #{status} with the standard status message" do
      assert ErrorJSON.render("#{unquote(status)}.json", %{}) ==
               %{errors: %{detail: unquote(message)}}
    end
  end

  test "uses the :detail assign when one is given" do
    assert ErrorJSON.render("401.json", %{detail: "Invalid email or password"}) ==
             %{errors: %{detail: "Invalid email or password"}}
  end

  test "ignores a :detail that is not a string" do
    assert ErrorJSON.render("404.json", %{detail: nil}) == %{errors: %{detail: "Not Found"}}
    assert ErrorJSON.render("404.json", %{detail: %{a: 1}}) == %{errors: %{detail: "Not Found"}}
  end

  test "ignores the assigns Phoenix passes when rendering an exception" do
    assigns = %{kind: :error, reason: %RuntimeError{message: "secret"}, stack: [], status: 500}

    assert ErrorJSON.render("500.json", assigns) ==
             %{errors: %{detail: "Internal Server Error"}}
  end
end
