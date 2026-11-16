# Writes development secrets into `.env` (run by ./setup.sh); never changes or prints existing values.

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

  # An empty value counts as unset, as in config/dotenv.exs.
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

  defp secret do
    48 |> :crypto.strong_rand_bytes() |> Base.encode64() |> binary_part(0, 64)
  end
end

DevEnv.run(Path.expand("../.env", __DIR__))
