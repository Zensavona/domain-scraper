defmodule Web.Router do
  use Web.Web, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :with_session do
    plug Guardian.Plug.VerifySession
    plug Guardian.Plug.LoadResource
    plug Web.CurrentUser
  end

  pipeline :login_required do
    plug Guardian.Plug.EnsureAuthenticated, handler: Web.GuardianErrorHandler
  end

  pipeline :admin_required do

  end

  # guest
  scope "/", Web do
    pipe_through [:browser, :with_session]

    get "/", PageController, :index

    resources "/sessions", SessionController, only: [:new, :create, :delete]
    resources "/users", UserController, only: [:new, :create]

    # logged in
    scope "/" do
      pipe_through [:login_required]

      resources "/users", UserController, only: [:show]
      resources "/crawls", CrawlController
      get "/crawlset/:id", CrawlController, :show_crawl_set
      # resources "/users", UserController, only: [:show] do
      #   resources "/posts", PostController
      # end
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", Web do
  #   pipe_through :api
  # end
end
