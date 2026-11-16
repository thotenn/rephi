defmodule RephiNew.MixProject do
  use Mix.Project

  @version "0.2.0"

  def project do
    [
      app: :rephi_new,
      version: @version,
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: []
    ]
  end

  def application do
    [extra_applications: [:logger, :crypto]]
  end
end
