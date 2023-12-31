defmodule TimeManagerApiWeb.WorkingtimesController do
  use TimeManagerApiWeb, :controller
  import Plug.Conn
  import Ecto.Query

  def index(conn, %{"userID" => userId} = params) when is_map(params) do
    case userId do
      nil ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "userId is required"})
      _ ->
        query = from(
          w in TimeManagerApi.Workingtimes,
          where: w.user_id == ^userId,
          select: %{id: w.id, start: w.start, end: w.end, user_id: w.user_id}
        )
        workingtime_result = TimeManagerApi.Repo.all(query)
        json(conn, workingtime_result)
    end
  end

  def index(conn, %{"userID" => userId, "end" => date_end, "start" => date_start}) do
    case {userId,date_end,date_start} do
      {nil,_,_} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "userId must be specified"})
      {_,nil,_} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "End date must be specified"})
      {_,_,nil} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "End date must be specified"})
      {_,_,_} ->
        date_start = String.to_integer(date_start)
        date_end = String.to_integer(date_end)
        convert_date_start = DateTime.from_unix!(date_start, :second)
        convert_date_end = DateTime.from_unix!(date_end, :second)
        query = from(
          w in TimeManagerApi.Workingtimes,
          where: w.start >= ^convert_date_start and w.end <= ^convert_date_end,
          select: w
        )
        workingtime_result = TimeManagerApi.Repo.all(query)
        json(conn,workingtime_result)
    end
  end

  def show(conn, %{"userID" => userId, "id" => id} = params) when is_map(params) do
    _query =
      from(
        w in TimeManagerApi.Workingtimes,
        where: w.id == ^id and w.user_id == ^userId,
        select: [w.id, w.start, w.end, w.user_id]
      )
      workingtime = TimeManagerApi.Repo.get(TimeManagerApi.Workingtimes,id)
      case workingtime do
        nil ->
          conn
          |> put_status(:not_found)
          |> json(%{error: "Workingtime with the id #{id} and the userId #{userId} doesn't exist"})
        workingtime ->
          json(conn,workingtime)
      end
    json(conn,workingtime)
  end

  def create(conn, %{"userID" => userId, "workingtime" => workingtime_param}) when is_binary(userId) do
    user_id = String.to_integer(userId)
    user = TimeManagerApi.Repo.get(TimeManagerApi.User,userId)
    case user do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "User not found"})
      _ ->
        merged_params = Map.put(workingtime_param,"user_id",user_id)
        changeset = TimeManagerApi.Workingtimes.changeset(%TimeManagerApi.Workingtimes{}, merged_params)
        try do
          case TimeManagerApi.Repo.insert(changeset) do
            {:ok, workingtime} ->
              conn
              |> put_status(:created)
              |> json(%{workingtime: workingtime})
            {:error, _changeset} ->
              conn
              |> put_status(:bad_request)
              |> json(%{error: "Bad request occurred"})
          end
        rescue
          _ ->
            conn
            |> put_status(:internal_server_error)
            |> json(%{error: "Internal server error"})
        end
    end
  end

  def update(conn, %{"id" => id, "workingtime" => workingtime_param}) do
    workingtime = TimeManagerApi.Repo.get(TimeManagerApi.Workingtimes, id)

    current_user = conn.assigns.current_user

    case workingtime do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{message: "Workingtime not found"})
      _ ->
        if (current_user.sub != workingtime.user_id) do
          conn
          |> put_status(:forbidden)
          |> json(%{message: "Forbidden"})
        else
          user_id = Map.get(workingtime_param,"user_id")
          user = TimeManagerApi.Repo.get(TimeManagerApi.User,user_id)
          case user do
            nil ->
              conn
              |> put_status(:not_found)
              |> json(%{error: "User not found"})
            _ ->
              workingtime = TimeManagerApi.Repo.get(TimeManagerApi.Workingtimes,id)
              case workingtime do
                nil ->
                  conn
                  |> put_status(:not_found)
                  |> json(%{message: "Workingtime not found"})
                _ ->
                  changeset = TimeManagerApi.Workingtimes.changeset(workingtime,workingtime_param)
                  case TimeManagerApi.Repo.update(changeset) do
                    {:ok, updated_workingtime} ->
                      conn
                      |> put_status(:ok)
                      |> json(%{workingtime: updated_workingtime})

                    {:error, _changeset} ->
                      conn
                      |> put_status(:bad_request)
                      |> json(%{message: "Bad request occurred"})
                  end
              end
          end
        end
    end
  end

  def delete(conn, %{"id" => id}) do
    workingtime = TimeManagerApi.Repo.get(TimeManagerApi.Workingtimes, id)

    current_user = conn.assigns.current_user

    case workingtime do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{message: "Workingtime not found"})
      _ ->
        if (current_user.sub != workingtime.user_id) do
          conn
          |> put_status(:forbidden)
          |> json(%{message: "Forbidden"})
        else
          case TimeManagerApi.Repo.delete(workingtime) do
            {:ok,_} ->
              conn
              |> put_status(:ok)
              |> json(%{message: "Workingtime deleted"})

            _ ->
              conn
              |> put_status(:internal_server_error)
              |> json(%{message: "Failed to delete workingtime"})
          end
        end
    end
  end
end
