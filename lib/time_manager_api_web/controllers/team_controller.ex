defmodule TimeManagerApiWeb.TeamController do
  use TimeManagerApiWeb, :controller
  import Ecto.Query
  import Plug.Conn

  def create(conn, %{"team" => team_params, "user_id" => user_id}) do
    case TimeManagerApi.Repo.get(TimeManagerApi.User, String.to_integer(user_id)) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "L'utilisateur avec l'identifiant #{user_id} n'existe pas"})
      _ ->
        teamchangeset = TimeManagerApi.Team.changeset(%TimeManagerApi.Team{}, team_params)
        case TimeManagerApi.Repo.insert(teamchangeset) do
          {:ok, team} ->
            user_team_params = %{"user_id" => user_id, "team_id" => team.id, "is_owner" => true}
            changesetUserTeam = TimeManagerApi.UserTeam.changeset(%TimeManagerApi.UserTeam{}, user_team_params)
            case TimeManagerApi.Repo.insert(changesetUserTeam) do
              {:ok, _userTeam} ->
                conn
                |> put_status(:created)
                |> json(%{message: "L'équipe a été créée et le propriétaire a été défini"})
              {:error, _} ->
                conn
                |> put_status(:internal_server_error)
                |> json(%{error: "Une erreur s'est produite lors du réglage du propriétaire de l'équipe"})
            end
          {:error, _} ->
            conn
            |> put_status(:internal_server_error)
            |> json(%{error: "Une erreur s'est produite lors de la création de l'équipe"})
        end
    end
  end

  def update(conn, %{"team" => team_params, "teamId" => teamId}) do
    team = TimeManagerApi.Repo.get(TimeManagerApi.Team, String.to_integer(teamId))

    teamOwnerId = TimeManagerApi.Repo.one(from(
      ut in TimeManagerApi.UserTeam,
      where: ut.is_owner == true and ut.team_id == ^teamId,
      select: ut.user_id
    ))

    current_user = conn.assigns.current_user

    case team_params do
      nil ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "A bad request occurred"})
      _ ->
        if (current_user.sub != teamOwnerId) do
          conn
            |> put_status(:forbidden)
            |> json(%{message: "Forbidden"})
        else
          case team do
            nil ->
              conn
              |> put_status(:not_found)
              |> json(%{error: "The team with the id #{teamId} doesn't exist"})
            _ ->
              changeset = TimeManagerApi.Team.changeset(team, team_params)
              case TimeManagerApi.Repo.update(changeset) do
                {:ok, _updated_team} ->
                  conn
                  |> put_status(:ok)
                  |> json(%{message: "The team has been updated"})
                {:error, _changeset} ->
                  conn
                  |> put_status(:internal_server_error)
                  |> json(%{error: "An error occurred while the updating of the team"})
              end
          end
        end
    end
  end

  def delete(conn, %{"teamId" => team_id}) do
    team = TimeManagerApi.Repo.get(TimeManagerApi.Team, team_id)

    teamOwnerId = TimeManagerApi.Repo.one(from(
      ut in TimeManagerApi.UserTeam,
      where: ut.is_owner == true and ut.team_id == ^team_id,
      select: ut.user_id
    ))

    current_user = conn.assigns.current_user

    if (current_user.sub != teamOwnerId) do
      conn
        |> put_status(:forbidden)
        |> json(%{message: "Forbidden"})
    else
      case team do
        nil ->
          conn
          |> put_status(:not_found)
          |> json(%{error: "The team with the id #{team_id} doesn't exist"})
        _ -> {
          case TimeManagerApi.Repo.delete(team) do
            {:ok, _} ->
              conn
              |> put_status(:ok)
              |> json(%{message: "Team has been deleted"})
            {:error, _} ->
              conn
              |> put_status(:internal_server_error)
              |> json(%{error: "An error occurred while the deleting of the team"})
          end
        }
      end
    end
  end

  def getAllTeams(conn, _param) do
    query =
      from(
        t in TimeManagerApi.Team
      )
      teams = TimeManagerApi.Repo.all(query)
      json(conn, teams)
  end

  def getTeamById(conn, %{"teamId" => team_id}) do
    team = TimeManagerApi.Repo.get(TimeManagerApi.Team, team_id)

    case team do
      %TimeManagerApi.Team{} = team ->
        json(conn,team)
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Team with id #{team_id} doesn't exist"})
    end
  end

  def getTeamsImMemberOf(conn, %{"userId" => user_id}) do
    user = TimeManagerApi.Repo.get(TimeManagerApi.User, user_id)

    case user do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "User Not Found"})

      %TimeManagerApi.User{role: role} when role in [:manager, :general_manager] ->
        teams_im_member_of = TimeManagerApi.Repo.all(
          from t in TimeManagerApi.Team,
          join: ut in TimeManagerApi.UserTeam,
          on: ut.team_id == t.id,
          where: ut.user_id == ^user_id,
          select: t
        )

        conn
        |> put_status(:ok)
        |> json(%{teams: teams_im_member_of})

      _ ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Unauthorized"})
    end
  end

  def getMyOwnedTeams(conn, %{"userId" => user_id}) do
    user = TimeManagerApi.Repo.get(TimeManagerApi.User, user_id)

    case user do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "User Not Found"})

      %TimeManagerApi.User{role: role} when role in [:manager, :general_manager] ->
        owned_teams = TimeManagerApi.Repo.all(
          from t in TimeManagerApi.Team,
          join: ut in TimeManagerApi.UserTeam,
          on: ut.team_id == t.id,
          where: ut.user_id == ^user_id and ut.is_owner == true,
          select: t
        )

        conn
        |> put_status(:ok)
        |> json(%{teams: owned_teams})

      _ ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Unauthorized"})
    end
  end

  def getTeamUsersById(conn, %{"teamId" => team_id}) do
    team_id = String.to_integer(team_id)

    team = TimeManagerApi.Repo.get(TimeManagerApi.Team, team_id)

    case team do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{"message" => "Team Not Found"})

      _ ->
        users_in_team = TimeManagerApi.Repo.all(
          from u in TimeManagerApi.User,
          join: ut in TimeManagerApi.UserTeam,
          on: u.id == ut.user_id,
          where: ut.team_id == ^team_id,
          select: %{user: u, is_owner: ut.is_owner}
        )

        users = Enum.map(users_in_team, fn ut ->
          %{id: ut.user.id, username: ut.user.username, email: ut.user.email, role: ut.user.role, is_owner: ut.is_owner}
        end)

        conn
        |> put_status(:ok)
        |> json(%{users: users})
    end
  end

  def addUserIntoTeam(conn, %{"userId" => userId, "teamId" => teamId}) do
    user = TimeManagerApi.Repo.get(TimeManagerApi.User, String.to_integer(userId))

    teamOwnerId = TimeManagerApi.Repo.one(from(
      ut in TimeManagerApi.UserTeam,
      where: ut.is_owner == true and ut.team_id == ^teamId,
      select: ut.user_id
    ))

    current_user = conn.assigns.current_user

    if (current_user.sub != teamOwnerId) do
      conn
        |> put_status(:forbidden)
        |> json(%{message: "Forbidden"})
    else
      case user do
        nil ->
          conn
          |> put_status(:not_found)
          |> json(%{error: "L'utilisateur avec l'identifiant #{userId} n'existe pas"})
        _ ->
          team = TimeManagerApi.Repo.get(TimeManagerApi.Team, String.to_integer(teamId))
          case team do
            nil ->
              conn
              |> put_status(:not_found)
              |> json(%{error: "L'équipe avec l'identifiant #{teamId} n'existe pas"})
            _ ->
              user_team = %{"team_id" => teamId, "user_id" => userId, "is_owner" => false}
              changeset = TimeManagerApi.UserTeam.changeset(%TimeManagerApi.UserTeam{}, user_team)
              case TimeManagerApi.Repo.insert(changeset) do
                {:ok, _} ->
                  conn
                  |> put_status(:created)
                  |> json(%{message: "L'utilisateur avec l'identifiant #{userId} a été ajouté à l'équipe avec l'identifiant #{teamId}"})
                {:error, _} ->
                  conn
                  |> put_status(:internal_server_error)
                  |> json(%{error: "Une erreur s'est produite, erreur interne du serveur"})
              end
          end
      end
    end
  end

  def deleteUserFromTeam(conn, %{"userId" => userId, "teamId" => teamId}) do
    query = from(ut in TimeManagerApi.UserTeam, where: ut.user_id == ^userId and ut.team_id == ^teamId)

    teamOwnerId = TimeManagerApi.Repo.one(from(
      ut in TimeManagerApi.UserTeam,
      where: ut.is_owner == true and ut.team_id == ^teamId,
      select: ut.user_id
    ))

    current_user = conn.assigns.current_user

    if (current_user.sub != teamOwnerId && current_user.sub != String.to_integer(userId)) do
      conn
        |> put_status(:forbidden)
        |> json(%{message: "Forbidden"})
    else
      case TimeManagerApi.Repo.delete_all(query) do
        {1, _} ->
          conn
          |> put_status(:ok)
          |> json(%{message: "The user has been removed of the team with the id #{teamId}"})
        {0, _}->
          conn
          |> put_status(:not_found)
          |> json(%{error: "The user with the id #{userId} is not in the team with the id #{teamId}"})
        _ ->
          conn
          |> put_status(:internal_server_error)
          |> json(%{error: "An error occurred while the removing of the user in the team"})
      end
    end
  end

  def grantOwnerRole(conn, %{"teamId" => teamId, "userId" => userId}) do
    teamOwnerId = TimeManagerApi.Repo.one(from(
      ut in TimeManagerApi.UserTeam,
      where: ut.is_owner == true and ut.team_id == ^teamId,
      select: ut.user_id
    ))

    current_user = conn.assigns.current_user

    if (current_user.sub != teamOwnerId) do
      conn
      |> put_status(:forbidden)
      |> json(%{message: "Forbidden"})
    else
      TimeManagerApi.Repo.update_all(
        from(ut in TimeManagerApi.UserTeam, where: ut.user_id == ^current_user.sub and ut.team_id == ^teamId),
        set: [is_owner: false]
      )
      TimeManagerApi.Repo.update_all(
        from(ut in TimeManagerApi.UserTeam, where: ut.user_id == ^userId and ut.team_id == ^teamId),
        set: [is_owner: true]
      )

      conn
      |> put_status(:ok)
      |> json(%{message: "Ownership role granted"})
    end
  end
end
