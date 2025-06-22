defmodule RephiNew.MixProject do
  use Mix.Project

  @version "0.0.1"
  @source_url "https://github.com/thotenn/rephi"

  def project do
    [
      app: :rephi_new,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      description: "Rephi project generator",
      source_url: @source_url
    ]
  end

  def application do
    [
      extra_applications: [:logger, :eex]
    ]
  end

  defp deps do
    []
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url
      },
      maintainers: ["thotenn"],
      files: ~w(lib templates mix.exs README.md)
    ]
  end
end