defmodule Rephi.Repo.Migrations.CreateNotifications do
  @moduledoc """
  Every notification sent (`Rephi.Notifications`), counted by the dashboard.
  """
  use Ecto.Migration

  def change do
    create table(:notifications) do
      add :sender_id, references(:users, on_delete: :nilify_all)
      add :recipient_id, references(:users, on_delete: :nilify_all)
      add :message, :text, null: false
      add :scope, :string, null: false

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create constraint(:notifications, :notifications_scope_check,
             check: "scope IN ('broadcast', 'self', 'direct')"
           )

    create index(:notifications, [:sender_id])
    create index(:notifications, [:recipient_id])
    create index(:notifications, [:scope])
  end
end
