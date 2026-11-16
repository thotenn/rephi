defmodule RephiNew.Secrets do
  @moduledoc """
  Gives a new project its own secrets.

  The template commits, like `mix phx.new` does, the values that development
  and test need to boot without any setup:

    * `secret_key_base` of the endpoint in `config/dev.exs` (the default of
      `SECRET_KEY_BASE`) and `config/test.exs`;
    * `secret_key` of Guardian (the JWT signing key) in `config/dev.exs` and
      `config/test.exs`;
    * `signing_salt` of the session cookie (`endpoint.ex`) and of LiveView
      (`config/config.exs`).

  None of them is used in production, which reads `SECRET_KEY_BASE` and
  `GUARDIAN_SECRET_KEY` from the environment, but the salts are compiled into
  the release, and every project must still have values nobody else knows.
  Each one is replaced by a fresh random value of the same kind.
  """

  # Pattern, kind of value, and how many the template must have. A template
  # that does not match exactly is refused instead of generating a project
  # that silently shares a secret with every other one.
  @rules [
    {:secret_key_base,
     ~r/(secret_key_base:\s*(?:System\.get_env\(\s*"SECRET_KEY_BASE",\s*)?)"[^"]*"/, 2},
    {:guardian_secret_key, ~r/(secret_key:\s*)"[^"]*"/, 2},
    {:signing_salt, ~r/(signing_salt:\s*)"[^"]*"/, 2}
  ]

  @doc """
  The files, among the given relative paths, whose secrets are replaced:
  `config/*.exs` and `lib/*_web/endpoint.ex`.
  """
  @spec files_in([Path.t()]) :: [Path.t()]
  def files_in(paths) do
    Enum.filter(paths, fn path ->
      case Path.split(path) do
        ["config", file] -> Path.extname(file) == ".exs"
        ["lib", web, "endpoint.ex"] -> String.ends_with?(web, "_web")
        _ -> false
      end
    end)
  end

  @doc """
  Replaces the secrets of the given `{path, contents}` files.

  Returns `{:ok, files}` with the new contents, or `{:error, message}` when the
  template does not have exactly the expected secrets.
  """
  @spec regenerate([{Path.t(), String.t()}]) ::
          {:ok, [{Path.t(), String.t()}]} | {:error, String.t()}
  def regenerate(files) do
    {files, counts} = Enum.map_reduce(files, %{}, &replace_file/2)

    mismatches =
      for {kind, _regex, expected} <- @rules, Map.get(counts, kind, 0) != expected do
        "#{kind}: expected #{expected}, found #{Map.get(counts, kind, 0)}"
      end

    case mismatches do
      [] ->
        {:ok, files}

      _ ->
        {:error,
         "The template's committed secrets are not the expected ones (" <>
           Enum.join(mismatches, "; ") <>
           "). Refusing to generate a project that would share them."}
    end
  end

  defp replace_file({path, contents}, counts) do
    Enum.reduce(@rules, {{path, contents}, counts}, fn {kind, regex, _}, {{path, text}, acc} ->
      found = length(Regex.scan(regex, text))
      text = Regex.replace(regex, text, fn _, prefix -> prefix <> inspect(generate(kind)) end)
      {{path, text}, Map.update(acc, kind, found, &(&1 + found))}
    end)
  end

  @doc """
  A new random value: 64 characters for keys, 8 for salts (what
  `mix phx.gen.secret` and `mix phx.new` use).
  """
  @spec generate(atom()) :: String.t()
  def generate(:signing_salt), do: random(8)
  def generate(_key), do: random(64)

  defp random(length) do
    length
    |> :crypto.strong_rand_bytes()
    |> Base.encode64(padding: false)
    |> binary_part(0, length)
  end
end
