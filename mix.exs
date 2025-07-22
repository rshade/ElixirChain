defmodule ElixirChain.MixProject do
  use Mix.Project

  def project do
    [
      app: :elixir_chain,
      version: "0.1.0",
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      dialyzer: [
        plt_file: {:no_warn, "priv/plts/elixir_chain.plt"},
        plt_add_apps: [:mix, :ex_unit]
      ],
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "test.watch": :test
      ],

      # Docs
      name: "ElixirChain",
      source_url: "https://github.com/rshade/ElixirChain",
      homepage_url: "https://github.com/rshade/ElixirChain",
      docs: [
        main: "ElixirChain",
        extras: ["README.md", "elixir_chain_design_doc.md", "CLAUDE.md"],
        groups_for_modules: [
          "Agent System": [
            ElixirChain.Agent,
            ElixirChain.Agent.Registry,
            ElixirChain.Agent.Supervisor
          ],
          "LLM Providers": [
            ElixirChain.LLM.Behaviour,
            ElixirChain.LLM.OpenAI,
            ElixirChain.LLM.Anthropic,
            ElixirChain.LLM.Local,
            ElixirChain.LLM.Router
          ],
          "Memory System": [
            ElixirChain.Memory,
            ElixirChain.Memory.Storage,
            ElixirChain.Memory.VectorStore,
            ElixirChain.Memory.Compression
          ],
          "Tool System": [
            ElixirChain.Tool.Behaviour,
            ElixirChain.Tool.Registry
          ],
          "Chain Execution": [
            ElixirChain.Chain,
            ElixirChain.Chain.Parallel,
            ElixirChain.Chain.Conditional,
            ElixirChain.Chain.Retry
          ]
        ]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :runtime_tools],
      mod: {ElixirChain.Application, []}
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # Core dependencies
      {:jason, "~> 1.4"},
      {:httpoison, "~> 2.0"},
      {:telemetry, "~> 1.2"},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.0"},
      
      # Database
      {:ecto_sql, "~> 3.10"},
      {:postgrex, "~> 0.17"},
      {:pgvector, "~> 0.2"},
      
      # Caching
      {:redix, "~> 1.3"},
      {:cachex, "~> 3.6"},
      
      # Streaming
      {:gen_stage, "~> 1.2"},
      {:flow, "~> 1.2"},
      {:broadway, "~> 1.0"},
      
      # HTTP and WebSockets
      {:mint, "~> 1.5"},
      {:finch, "~> 0.16"},
      {:websock_adapter, "~> 0.5"},
      
      # Utilities
      {:nimble_options, "~> 1.0"},
      {:typed_struct, "~> 0.3"},
      {:retry, "~> 0.18"},
      {:timex, "~> 3.7"},
      
      # Testing
      {:ex_machina, "~> 2.7", only: [:dev, :test]},
      {:mox, "~> 1.0", only: :test},
      {:bypass, "~> 2.1", only: :test},
      {:excoveralls, "~> 0.18", only: :test},
      {:mix_test_watch, "~> 1.1", only: [:dev, :test], runtime: false},
      
      # Development
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false},
      {:ex_doc, "~> 0.30", only: :dev, runtime: false},
      {:observer_cli, "~> 1.7", only: :dev}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "test.watch": ["test.watch --exclude integration"],
      "deps.audit": ["deps.unlock --check-unused", "hex.audit"],
      quality: ["format --check-formatted", "credo --strict", "dialyzer"],
      docs: ["docs --formatter html --output doc/"]
    ]
  end
end