# Seeds the default roles, permissions and the first administrator:
#
#     mix run priv/repo/seeds.exs
#
# Safe to run again: nothing is duplicated and nothing that exists is
# changed. The administrator comes from ADMIN_EMAIL / ADMIN_PASSWORD, which
# are required outside development. See `Rephi.Seeds` for the details.

case Rephi.Seeds.run() do
  {:ok, %{admin: admin}} ->
    IO.puts("Seeded the default roles and permissions.")

    case admin do
      {:created, email} ->
        IO.puts("Administrator created: #{email}")

      {:existing, email} ->
        IO.puts("Administrator already exists: #{email} (password unchanged)")

      {default, email} when default in [:default_created, :default_existing] ->
        IO.puts(
          :stderr,
          IO.ANSI.format([
            :yellow,
            """

            WARNING: #{email} is the well-known development administrator \
            (password "password123!!"), seeded because ADMIN_EMAIL and \
            ADMIN_PASSWORD are not set. Never expose this database.
            """
          ])
        )

      :skipped ->
        IO.puts("No administrator seeded (ADMIN_EMAIL / ADMIN_PASSWORD are not set).")
    end

  {:error, message} ->
    Mix.raise("Seeding failed, nothing was changed: " <> message)
end
