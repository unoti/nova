defmodule Nova.MixProject do
  use Mix.Project

  def project do
    [
      app: :nova,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      description: description(),
      package: package()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:hackney, "~> 1.20"},
      {:jason, "~> 1.4"}
    ]
  end

  defp aliases do
    [
      "test.unit": ["test"],
      "test.all": ["test --include integration"],
      "test.integration": ["test --only integration"],
      "test.openai": ["test test/nova/llm/drivers/openai_test.exs --include skip"]
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
