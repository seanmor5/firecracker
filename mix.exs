defmodule Firecracker.MixProject do
  use Mix.Project

  @source_url "https://github.com/seanmor5/firecracker"
  @version "0.1.0"

  def project do
    [
      app: :firecracker,
      version: @version,
      elixirc_paths: elixirc_paths(Mix.env()),
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      description: "An Elixir SDK for interacting with Firecracker Virtual Machines",
      package: package()
    ]
  end

  def cli do
    [preferred_envs: [docs: :docs, "hex.publish": :docs]]
  end

  defp elixirc_paths(:test), do: ~w(lib test/support)
  defp elixirc_paths(_), do: ~w(lib)

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:req, "~> 0.5"},
      {:nimble_options, "~> 1.0"},
      {:p, github: "seanmor5/p"},
      {:ex_doc, "~> 0.34", only: :docs, runtime: false}
    ]
  end

  defp package do
    [
      maintainers: ["Sean Moriarity"],
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => @source_url}
    ]
  end

  defp docs do
    [
      main: "Firecracker",
      source_ref: "v#{@version}",
      source_url: @source_url,
      groups_for_docs: [
        Creation: &(&1[:type] == :creation),
        Configuration: &(&1[:type] == :configuration),
        Lifecycle: &(&1[:type] == :lifecycle),
        Snapshots: &(&1[:type] == :snapshot),
        Inspection: &(&1[:type] == :inspection),
        Jailer: &(&1[:type] == :jailer),
        Helpers: &(&1[:type] == :helper)
      ]
    ]
  end
end
