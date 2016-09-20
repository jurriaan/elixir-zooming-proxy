defmodule ElixirProxy.Mixfile do
  use Mix.Project

  def project do
    [app: :elixir_proxy,
     version: "0.0.2",
     elixir: "~> 1.3",
     deps: deps]
  end

  def application do
    [mod: { ElixirProxy, [] },
    applications: [:cowboy, :ranch, :httpotion, :plug]]
  end

  defp deps do
    [
      { :cowboy, "~> 1.0" },
      { :httpotion, "~> 3.0.1"},
      { :plug, "~> 1.2.0" },
      { :jiffy, github: "davisp/jiffy" }
    ]
  end
end
