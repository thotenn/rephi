defmodule Rephi.Release do
  @moduledoc """
  Database tasks for a release, where Mix is not available (`bin/migrate`,
  `bin/seed`).
  """

  @app :rephi

  @doc """
  Runs every pending migration of every repo.
  """
  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end

    :ok
  end

  @doc """
  Rolls `repo` back to `version`.
  """
  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
    :ok
  end

  @doc """
  Seeds the default roles, permissions and the first administrator. Raises
  (exit status 1 from `bin/seed`) when seeding fails; nothing is changed then.
  """
  def seed do
    load_app()

    {:ok, result, _} = Ecto.Migrator.with_repo(Rephi.Repo, fn _repo -> Rephi.Seeds.run() end)

    case result do
      {:ok, %{admin: admin, stale_grants: stale_grants}} ->
        IO.puts("Seeded the default roles and permissions. Administrator: #{describe(admin)}")

        for {role, permission} <- stale_grants do
          IO.puts(
            "NOTICE: role #{role} holds #{permission}, which the default seed no longer " <>
              "grants. Revoke it if it is not wanted (see Rephi.Seeds)."
          )
        end

        :ok

      {:error, message} ->
        raise "seeding failed: #{message}"
    end
  end

  defp describe({:created, email}), do: "#{email} (created)"
  defp describe({:existing, email}), do: "#{email} (already existed, unchanged)"
  defp describe({_default, email}), do: "#{email} (the well-known development administrator)"
  defp describe(:skipped), do: "none (ADMIN_EMAIL / ADMIN_PASSWORD are not set)"

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    # Many platforms require SSL when connecting to the database
    Application.ensure_all_started(:ssl)
    Application.ensure_loaded(@app)
  end
end
