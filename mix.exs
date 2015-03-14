defmodule ElixirProxy.Mixfile do
  use Mix.Project

  def project do
    [app: :elixir_proxy,
     version: "0.0.1",
     elixir: "~> 1.1-dev",
     deps: deps]
  end

  def application do
    [mod: { ElixirProxy, [] },
    applications: [:cowboy, :ranch, :httpoison, :plug]]
  end

  defp deps do
    [
      { :cowboy, "~> 1.0.0" },
      { :httpoison, "~> 0.6"},
      { :plug, "~> 0.11.1" },
      { :jiffy, github: "davisp/jiffy" }
    ]
  end
end
