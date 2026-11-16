defmodule Rephi.DotEnv do
  @moduledoc """
  Minimal `.env` loader for development. Lives in `config/` because it runs
  before the project compiles; variables already set in the environment win.
  """

  @doc "Loads the file at `path` into the environment; returns the names it set."
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

  @doc "Parses `.env` contents into `{name, value}` pairs, in file order."
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

  defp double_quoted("", acc), do: acc
end
