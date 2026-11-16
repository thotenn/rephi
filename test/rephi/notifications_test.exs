defmodule Rephi.NotificationsTest do
  use Rephi.DataCase, async: true

  import Rephi.AuthTestHelpers

  alias Rephi.Accounts
  alias Rephi.Notifications
  alias Rephi.Notifications.Notification

  describe "record/1" do
    test "stores each scope with its sender and recipient" do
      sender = create_user()
      recipient = create_user()

      assert {:ok, %Notification{scope: "broadcast", recipient_id: nil, inserted_at: at}} =
               Notifications.record(%{message: "Hi", scope: "broadcast", sender_id: sender.id})

      assert %DateTime{microsecond: {_, 6}} = at

      assert {:ok, %Notification{scope: "self"}} =
               Notifications.record(%{
                 message: "Me",
                 scope: "self",
                 sender_id: sender.id,
                 recipient_id: sender.id
               })

      assert {:ok, %Notification{scope: "direct", sender_id: nil}} =
               Notifications.record(%{
                 message: "You",
                 scope: "direct",
                 recipient_id: recipient.id
               })
    end

    test "refuses an unknown scope, a missing message and misplaced recipients" do
      user = create_user()

      assert {:error, changeset} = Notifications.record(%{message: "x", scope: "everyone"})
      assert "is invalid" in errors_on(changeset).scope

      assert {:error, changeset} = Notifications.record(%{scope: "broadcast"})
      assert "can't be blank" in errors_on(changeset).message

      assert {:error, changeset} =
               Notifications.record(%{message: "x", scope: "broadcast", recipient_id: user.id})

      assert "must be empty for a broadcast" in errors_on(changeset).recipient_id

      for scope <- ["self", "direct"] do
        assert {:error, changeset} = Notifications.record(%{message: "x", scope: scope})
        assert "can't be blank" in errors_on(changeset).recipient_id
      end
    end

    test "refuses an unknown user" do
      assert {:error, changeset} =
               Notifications.record(%{message: "x", scope: "broadcast", sender_id: -1})

      assert "does not exist" in errors_on(changeset).sender_id
    end
  end

  describe "counts" do
    test "broadcasts by anyone and everything a user sent" do
      me = create_user()
      other = create_user()
      before = Notifications.count_broadcasts()

      for {scope, sender, recipient} <- [
            {"broadcast", me, nil},
            {"broadcast", other, nil},
            {"self", me, me},
            {"direct", other, me}
          ] do
        {:ok, _} =
          Notifications.record(%{
            message: "x",
            scope: scope,
            sender_id: sender.id,
            recipient_id: recipient && recipient.id
          })
      end

      assert Notifications.count_broadcasts() == before + 2
      assert Notifications.count_sent_by(me) == 2
      assert Notifications.count_sent_by(other.id) == 2
      assert Notifications.count_sent_by(create_user()) == 0
    end

    test "deleting a user keeps its notifications without a sender" do
      user = create_user()

      {:ok, notification} =
        Notifications.record(%{
          message: "x",
          scope: "self",
          sender_id: user.id,
          recipient_id: user.id
        })

      {:ok, _} = Accounts.delete_user(user)

      assert %Notification{sender_id: nil, recipient_id: nil} =
               Repo.get!(Notification, notification.id)
    end
  end
end
