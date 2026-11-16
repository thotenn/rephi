defmodule Rephi.DotEnvTest do
  @moduledoc "SEC-21 / API-15: the development `.env` loader."
  use ExUnit.Case, async: false

  # config/config.exs already required it; this is a no-op unless the test
  # runs on its own in a fresh VM.
  Code.require_file("../../config/dotenv.exs", __DIR__)

  alias Rephi.DotEnv

  describe "parse/1" do
    test "plain assignments, comments and blank lines" do
      contents = """
      # a comment

      PORT=4000
      DB_NAME = rephi_dev
      """

      assert DotEnv.parse(contents) == [{"PORT", "4000"}, {"DB_NAME", "rephi_dev"}]
    end

    test "export prefix" do
      assert DotEnv.parse("export A=1\nexport\tB=2") == [{"A", "1"}, {"B", "2"}]
    end

    test "inline comments after whitespace, but # inside a value is kept" do
      assert DotEnv.parse("PORT=4000 # dev port\nURL=http://x/#frag") ==
               [{"PORT", "4000"}, {"URL", "http://x/#frag"}]
    end

    test "double quotes, with escapes and a comment after them" do
      assert DotEnv.parse(~S(A="p@ss word # 1" # comment)) == [{"A", "p@ss word # 1"}]
      assert DotEnv.parse(~S(B="line\nnext \"q\" \\")) == [{"B", "line\nnext \"q\" \\"}]
    end

    test "single quotes are literal" do
      assert DotEnv.parse(~S(A='kept $as \n is' # c)) == [{"A", ~S(kept $as \n is)}]
    end

    test "empty values" do
      assert DotEnv.parse("A=\nB=\"\"") == [{"A", ""}, {"B", ""}]
    end

    test "lines that are not assignments are ignored" do
      assert DotEnv.parse("just text\n=value\n1BAD=x\nBAD-NAME=x\nOK=1") == [{"OK", "1"}]
    end

    test "CRLF line endings" do
      assert DotEnv.parse("A=1\r\nB=2\r\n") == [{"A", "1"}, {"B", "2"}]
    end

    test "the value keeps everything after the first =" do
      assert DotEnv.parse("URL=ecto://u:p@h/db?a=b") == [{"URL", "ecto://u:p@h/db?a=b"}]
    end
  end

  describe "load/1" do
    @moduletag :tmp_dir

    setup %{tmp_dir: dir} do
      names = ~w(REPHI_DOTENV_A REPHI_DOTENV_B REPHI_DOTENV_EMPTY)
      on_exit(fn -> Enum.each(names, &System.delete_env/1) end)
      {:ok, path: Path.join(dir, ".env")}
    end

    test "sets the variables of the file", %{path: path} do
      File.write!(path, "REPHI_DOTENV_A=from-file\n")

      assert DotEnv.load(path) == ["REPHI_DOTENV_A"]
      assert System.get_env("REPHI_DOTENV_A") == "from-file"
    end

    test "never overrides a variable that is already set", %{path: path} do
      System.put_env("REPHI_DOTENV_A", "from-shell")
      File.write!(path, "REPHI_DOTENV_A=from-file\nREPHI_DOTENV_B=b\n")

      assert DotEnv.load(path) == ["REPHI_DOTENV_B"]
      assert System.get_env("REPHI_DOTENV_A") == "from-shell"
    end

    test "an empty value leaves the variable unset", %{path: path} do
      File.write!(path, "REPHI_DOTENV_EMPTY=\n")

      assert DotEnv.load(path) == []
      assert System.get_env("REPHI_DOTENV_EMPTY") == nil
    end

    test "a missing file is not an error", %{path: path} do
      assert DotEnv.load(path) == []
    end
  end

  test "config/config.exs only loads it in development" do
    source = File.read!(Path.expand("../../config/config.exs", __DIR__))
    assert source =~ ~r/if config_env\(\) == :dev do\s+Rephi\.DotEnv\.load/
  end
end
