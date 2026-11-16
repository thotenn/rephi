defmodule RephiNew.Secrets do
  @moduledoc """
  Replaces the dev/test secrets and signing salts the template commits with fresh
  random values, so no two projects share them.
  """

  # Exact counts: a template that does not match is refused rather than sharing a secret.
  @rules [
    {:secret_key_base,
     ~r/(secret_key_base:\s*(?:System\.get_env\(\s*"SECRET_KEY_BASE",\s*)?)"[^"]*"/, 2},
    {:guardian_secret_key, ~r/(secret_key:\s*)"[^"]*"/, 2},
    {:signing_salt, ~r/(signing_salt:\s*)"[^"]*"/, 2}
  ]

  @doc "The files, among the given relative paths, whose secrets are replaced."
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
  Replaces the secrets of the given `{path, contents}` files, or returns an error
  when the template does not have exactly the expected secrets.
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

  @doc "A new random value: 64 characters for keys, 8 for salts."
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
