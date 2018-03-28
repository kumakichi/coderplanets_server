defmodule Helper.ORM do
  @moduledoc """
  General CORD functions
  """
  import Ecto.Query, warn: false
  import Helper.Utils, only: [done: 1, done: 3]

  alias MastaniServer.Repo
  alias Helper.QueryBuilder

  @doc """
  a wrap for paginate request
  """
  def paginater(queryable, page: page, size: size) do
    queryable |> Repo.paginate(page: page, page_size: size)
  end

  @doc """
  wrap Repo.get with preload and result/errer format handle
  """
  def find(queryable, id, preload: preload) do
    queryable
    |> preload(^preload)
    |> Repo.get(id)
    |> done(queryable, id)
  end

  @doc """
  simular to Repo.get/3, with standard result/error handle
  """
  def find(queryable, id) do
    queryable
    |> Repo.get(id)
    |> done(queryable, id)
  end

  @doc """
  simular to Repo.get_by/3, with standard result/error handle
  """
  def find_by(queryable, clauses) do
    queryable
    |> Repo.get_by(clauses)
    |> case do
      nil ->
        {:error, not_found_formater(queryable, clauses)}

      result ->
        {:ok, result}
    end
  end

  @doc """
  return pageinated Data required by filter
  """
  def find_all(queryable, %{page: page, size: size} = filter) do
    queryable
    |> QueryBuilder.filter_pack(filter)
    |> paginater(page: page, size: size)
    |> done()
  end

  @doc """
  return  Data required by filter
  """
  def find_all(queryable, filter) do
    queryable |> QueryBuilder.filter_pack(filter) |> Repo.all() |> done()
  end

  @doc """
  Require queryable has a views fields to count the views of the queryable Modal
  """
  def read(queryable, id, inc: :views) do
    with {:ok, result} <- find(queryable, id) do
      result |> inc_views_count(queryable) |> done()
    end
  end

  defp inc_views_count(content, queryable) do
    {1, [result]} =
      Repo.update_all(
        from(p in queryable, where: p.id == ^content.id),
        [inc: [views: 1]],
        returning: [:views]
      )

    put_in(content.views, result.views)
  end

  @doc """
  NOTICE: this should be use together with Authorize/OwnerCheck etc Middleware
  DO NOT use it directly
  """
  def delete(content), do: Repo.delete(content)

  def find_delete(queryable, id) do
    with {:ok, content} <- find(queryable, id) do
      delete(content)
    end
  end

  @doc """
  NOTICE: this should be use together with Authorize/OwnerCheck etc Middleware
  DO NOT use it directly
  """
  def update(content, attrs) do
    content
    |> content.__struct__.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  return the total count of a Modal based on id column
  also support filters
  """
  def count(queryable, filter \\ %{}) do
    queryable
    |> QueryBuilder.filter_pack(filter)
    |> select([f], count(f.id))
    |> Repo.one()
  end

  defp not_found_formater(queryable, id) when is_integer(id) or is_binary(id) do
    modal_sortname = queryable |> to_string |> String.split(".") |> List.last()
    "#{modal_sortname}(#{id}) not found"
  end

  defp not_found_formater(queryable, clauses) do
    modal_sortname = queryable |> to_string |> String.split(".") |> List.last()

    detail =
      clauses
      |> Enum.into(%{})
      |> Map.values()
      |> List.first()
      |> to_string

    "#{modal_sortname}(#{detail}) not found"
  end
end
