defmodule Nova.MixProject do
  use Mix.Project

  def project do
    [
      app: :nova,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # HTTP Client
      {:hackney, "~> 1.20"},
      # JSON parsing
      {:jason, "~> 1.4"}
    ]
  end

  defp description do
    """
    Nova - A library for integrating AI into business workflows using Elixir.
    Makes it easy to work with LLMs and facilitates multi-agent workflows and interactive conversations.
    """
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/username/nova"}
    ]
  end
end
