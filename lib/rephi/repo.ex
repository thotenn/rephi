defmodule Rephi.Repo do
  use Ecto.Repo,
    otp_app: :rephi,
    adapter: Ecto.Adapters.Postgres
end
