# Writes the development secrets into `.env` (git-ignored):
#
#     elixir scripts/dev_env.exs
#
# `./setup.sh` runs it. It creates `.env` with a new SECRET_KEY_BASE and
# GUARDIAN_SECRET_KEY when the file does not exist, and adds whichever of the
# two is missing when it does. Values already set are never changed, and the
# values are never printed.
#
# Development also boots without them (config/dev.exs has defaults); a
# `.env` of your own keeps your local sessions and tokens signed with keys
# that are not in the repository. Production never reads `.env`: see
# `.env.example` for the variables a release needs.

defmodule DevEnv do
  @keys ~w(SECRET_KEY_BASE GUARDIAN_SECRET_KEY)

  def run(path) do
    existing = if File.exists?(path), do: File.read!(path), else: nil
    missing = Enum.reject(@keys, &set?(existing || "", &1))

    cond do
      missing == [] ->
        IO.puts(".env already has #{Enum.join(@keys, " and ")}")

      existing == nil ->
        File.write!(path, header() <> assignments(missing))
        File.chmod!(path, 0o600)
        IO.puts("Created .env with a new #{Enum.join(missing, " and ")}")

      true ->
        separator = if String.ends_with?(existing, "\n") or existing == "", do: "", else: "\n"
        File.write!(path, existing <> separator <> assignments(missing))
        IO.puts("Added a new #{Enum.join(missing, " and ")} to .env")
    end
  end

  # Whether `.env` assigns a non-empty value to `key` (`KEY=value`, with an
  # optional `export `). An empty value counts as not set, as it does for the
  # loader in config/dotenv.exs.
  defp set?(contents, key) do
    contents =~ ~r/^\s*(export\s+)?#{key}\s*=\s*[^\s#]/m
  end

  defp header do
    """
    # Local development settings (git-ignored). Variables already set in your
    # shell win over these. Every available setting is in .env.example.

    """
  end

  defp assignments(keys), do: Enum.map_join(keys, &"#{&1}=#{secret()}\n")

  # 64 characters, like `mix phx.gen.secret`.
  defp secret do
    48 |> :crypto.strong_rand_bytes() |> Base.encode64() |> binary_part(0, 64)
  end
end

DevEnv.run(Path.expand("../.env", __DIR__))
