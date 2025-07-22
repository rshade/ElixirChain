import Config

# Configure your database for test
config :elixir_chain, ElixirChain.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "elixir_chain_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

# Print only warnings and errors during test
config :logger, level: :warning

# Speed up tests by reducing iterations
config :bcrypt_elixir, :log_rounds, 1

# Test configuration
config :elixir_chain,
  # Use mock LLM providers in tests
  llm: [
    providers: [:mock],
    default_provider: :mock
  ],
  
  # Use in-memory storage for tests
  memory: [
    backend: :ets,
    persist: false
  ],
  
  # Disable distributed features in tests
  distributed: [
    enabled: false
  ]