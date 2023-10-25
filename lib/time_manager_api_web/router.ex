defmodule TimeManagerApiWeb.Router do
  use TimeManagerApiWeb, :router

  pipeline :api do
    plug :accepts, ["json", "html"]
  end

  scope "/", TimeManagerApiWeb, as: :browser do
    get "/", HomeController, :index
  end

  scope "/api", TimeManagerApiWeb do
    pipe_through :api

    scope "/workingtimes" do
      get "/:userID", WorkingtimesController, :getall
      get "/:userID/:id", WorkingtimesController, :getone
      post "/:userID", WorkingtimesController, :create
      put "/:id", WorkingtimesController, :update
      delete "/:id", WorkingtimesController, :delete
    end

    scope "/clocks" do
      get "/:userID", ClockController, :show
      post "/:userID", ClockController, :create
    end

    scope "/users" do
      get "", UserController, :index
      get "/:userID", UserController, :show
      post "", UserController, :create
      put "/:userID", UserController, :update
      delete "/:userID", UserController, :delete
    end

    scope "/teams" do
      get "", TeamController, :index
      get "/:teamID", TeamController, :show
      post "", TeamController, :create
      put "/:teamID", TeamController, :update
      delete "/:teamID", TeamController, :delete
    end
  end


  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:time_manager_api, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/api" do
      pipe_through [:fetch_session, :protect_from_forgery]


    end
  end
end
