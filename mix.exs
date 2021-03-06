defmodule DomainScraper.Mixfile do
  use Mix.Project

  def project do
    [apps_path: "apps",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  # Dependencies can be Hex packages:
  #
  #   {:my_dep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:my_dep, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options.
  #
  # Dependencies listed here are available only for this project
  # and cannot be accessed from applications inside the apps folder
  defp deps do
    [
      {:redix, ">= 0.0.0"},
      {:distillery, "~> 0.9"},
      {:edeliver, "~> 1.4.0"},
      {:lmgtfy, "~> 0.1.0"},
      {:dogstatsd, "0.0.3"},
    ]
  end
end
