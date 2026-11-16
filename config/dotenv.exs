defmodule Rephi.DotEnv do
  @moduledoc """
  Minimal `.env` loader for development.

  It lives next to the configuration files, and not under `lib/`, because it
  has to run before the project is compiled: `config/config.exs` requires this
  file and calls `load/1` on its very first lines, so every later
  `System.get_env/1` (in `config/dev.exs` and `config/runtime.exs`) already
  sees the values.

  Rules:

    * variables that are already set in the real environment always win, so
      `PORT=4040 mix phx.server` works whatever `.env` says;
    * it only runs in the `:dev` environment. Tests never read `.env`, and a
      release reads the real environment only;
    * a missing file is not an error.

  Supported syntax, one assignment per line:

      # a comment
      PORT=4000
      export DB_NAME=rephi_dev        # "export" is accepted and ignored
      DB_PASSWORD="p@ss word # 1"     # double quotes: \\n, \\" and \\\\ escapes
      PLAIN='kept $as is'             # single quotes: taken literally
      CORS_ORIGINS=http://localhost:3000   # trailing comment after whitespace
      SECRET_KEY_BASE=                # empty: the variable is left unset

  There is no variable interpolation and no multi-line values. Lines that are
  not an assignment are ignored.
  """

  @doc """
  Loads the file at `path` into the system environment.

  Returns the names of the variables it set. Variables that already exist and
  assignments with an empty value are skipped.
  """
  @spec load(Path.t()) :: [String.t()]
  def load(path) do
    case File.read(path) do
      {:ok, contents} ->
        for {key, value} <- parse(contents), value != "", System.get_env(key) == nil do
          System.put_env(key, value)
          key
        end

      {:error, _reason} ->
        []
    end
  end

  @doc """
  Parses the contents of a `.env` file into a list of `{name, value}` pairs,
  in file order.

  ## Examples

      iex> Rephi.DotEnv.parse(~s(export PORT=4000 # dev\\nNAME="a b"\\n))
      [{"PORT", "4000"}, {"NAME", "a b"}]

  """
  @spec parse(String.t()) :: [{String.t(), String.t()}]
  def parse(contents) when is_binary(contents) do
    contents
    |> String.split(["\r\n", "\n"])
    |> Enum.flat_map(&parse_line/1)
  end

  defp parse_line(line) do
    line = String.trim(line)

    with false <- line == "" or String.starts_with?(line, "#"),
         [key, value] <- line |> strip_export() |> String.split("=", parts: 2),
         key = String.trim(key),
         true <- key =~ ~r/\A[A-Za-z_][A-Za-z0-9_]*\z/ do
      [{key, parse_value(String.trim_leading(value))}]
    else
      _ -> []
    end
  end

  defp strip_export("export " <> rest), do: String.trim_leading(rest)
  defp strip_export("export\t" <> rest), do: String.trim_leading(rest)
  defp strip_export(line), do: line

  defp parse_value("\"" <> rest), do: double_quoted(rest, "")

  defp parse_value("'" <> rest) do
    case String.split(rest, "'", parts: 2) do
      [value, _comment] -> value
      # No closing quote: keep the text as written.
      [value] -> value
    end
  end

  defp parse_value(value) do
    # An unquoted value ends at the first "#" that follows whitespace.
    value
    |> String.split(~r/\s+#/, parts: 2)
    |> hd()
    |> String.trim()
  end

  defp double_quoted("\\n" <> rest, acc), do: double_quoted(rest, acc <> "\n")
  defp double_quoted("\\\"" <> rest, acc), do: double_quoted(rest, acc <> "\"")
  defp double_quoted("\\\\" <> rest, acc), do: double_quoted(rest, acc <> "\\")
  defp double_quoted("\"" <> _comment, acc), do: acc

  defp double_quoted(<<char::utf8, rest::binary>>, acc),
    do: double_quoted(rest, acc <> <<char::utf8>>)

  # No closing quote: keep the text as written.
  defp double_quoted("", acc), do: acc
end
