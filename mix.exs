defmodule BunnyRabbit.Mixfile do
  use Mix.Project

  @version "0.2.0"
  @elixir_version "~> 1.9"

  def project do
    [
      app: :bunny_rabbit,
      version: @version,
      elixir: @elixir_version,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),

      description: description(),
      package: package(),

      aliases: aliases(),
      dialyzer: dialyzer(),

      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [coveralls: :test, "coveralls.detail": :test, "coveralls.post": :test, "coveralls.html": :test]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "task", "test/support"]
  defp elixirc_paths(_), do: ["lib", "task"]

  defp deps do
    [
      {:amqp, "~> 2.1"},
      {:poolboy, "~> 1.5"},

      # DEV AND TEST
      {:dialyxir, "~> 1.0", only: :dev, runtime: false},
      {:credo, "~>1.0", only: :dev, runtime: false},
      {:mix_test_watch, "~> 1.0", only: :dev, runtime: false},
      {:excoveralls, "~> 0.12", only: :test},
    ]
  end

  defp description do
    """
    RabbitMQ channel pools
    """
  end

  defp package do
    [
      maintainers: ["Chris Douglas"],
      licenses: ["TODO"],
      links: %{"Github" => "TODO"},
      files: ~w(lib mix.exs README.md)
    ]
  end

  defp aliases do
    [
    ]
  end

  defp dialyzer do
    [
      plt_add_deps: :transitive,
      plt_add_apps: [:mix]
    ]
  end
end
