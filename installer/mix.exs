defmodule RephiNew.MixProject do
  use Mix.Project

  # Bump it with every change to the installer.
  @version "0.2.0"

  # The installer is distributed as a Mix archive built from this directory
  # (see README.md); it is not published to Hex.
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
