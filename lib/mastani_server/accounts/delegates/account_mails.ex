defmodule MastaniServer.Accounts.Delegate.AccountMails do
  import Ecto.Query, warn: false
  import Helper.Utils, only: [done: 1]
  import ShortMaps

  alias MastaniServer.Repo
  alias MastaniServer.Accounts.{User, MentionMail, NotificationMail}
  alias MastaniServer.Delivery
  alias Helper.ORM

  def fetch_mentions(
        %User{id: user_id} = user,
        %{page: page, size: size, read: read} = filter
      ) do
    with {:ok, mentions} <- Delivery.fetch_mentions(user, filter),
         {:ok, washed_mentions} <- wash_data(:mention, mentions.entries) do
      # IO.inspect washed_mentions, label: "insert fuck"
      MentionMail
      |> Repo.insert_all(washed_mentions)

      MentionMail
      |> where([m], m.to_user_id == ^user_id)
      |> where([m], m.read == ^read)
      |> ORM.paginater(~m(page size)a)
      |> done()
    end
  end

  def fetch_notifications(
        %User{id: user_id} = user,
        %{page: page, size: size, read: read} = filter
      ) do
    with {:ok, notifications} <- Delivery.fetch_notifications(user, filter),
         {:ok, washed_notifications} <- wash_data(:notification, notifications.entries) do
      # IO.inspect washed_mentions, label: "insert fuck"
      NotificationMail
      |> Repo.insert_all(washed_notifications)

      NotificationMail
      |> where([m], m.to_user_id == ^user_id)
      |> where([m], m.read == ^read)
      |> ORM.paginater(~m(page size)a)
      |> done()
    end
  end

  # TODO
  def mark_mail_read(%MentionMail{id: id}, %User{id: user_id}) do
    with {:ok, mention} <- MentionMail |> ORM.find_by(id: id, to_user_id: user_id) do
      mention |> ORM.update(%{read: true})
    end
  end

  def mark_mail_read(%NotificationMail{id: id}, %User{id: user_id}) do
    with {:ok, notification} <- NotificationMail |> ORM.find_by(id: id, to_user_id: user_id) do
      notification |> ORM.update(%{read: true})
    end
  end

  def mark_mail_read_all(%User{} = user, :mention) do
    query =
      MentionMail
      |> where([m], m.to_user_id == ^user.id)

    Repo.update_all(query, set: [read: true])

    Delivery.mark_read_all(user, :mention)
  end

  def mark_mail_read_all(%User{} = user, :notification) do
    query =
      NotificationMail
      |> where([m], m.to_user_id == ^user.id)

    Repo.update_all(query, set: [read: true])

    Delivery.mark_read_all(user, :notification)
  end

  defp wash_data(:mention, []), do: {:ok, []}
  defp wash_data(:notification, []), do: {:ok, []}

  # TODO: refactor
  defp wash_data(:mention, list) do
    # struct_list |> Enum.map(fn(x)-> Map.from_struct(x)  end)
    convert =
      list
      |> Enum.map(
        &(Map.from_struct(&1)
          |> Map.delete(:__meta__)
          |> Map.delete(:id)
          |> Map.delete(:from_user)
          |> Map.delete(:to_user))
      )

    {:ok, convert}
  end

  defp wash_data(:notification, list) do
    # struct_list |> Enum.map(fn(x)-> Map.from_struct(x)  end)
    convert =
      list
      |> Enum.map(
        &(Map.from_struct(&1)
          |> Map.delete(:__meta__)
          |> Map.delete(:id)
          |> Map.delete(:from_user)
          |> Map.delete(:to_user))
      )

    {:ok, convert}
  end
end
