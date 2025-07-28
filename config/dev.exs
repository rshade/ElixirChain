import Config

# Configure your database
config :elixir_chain, ElixirChain.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "elixir_chain_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

# For development, we want more verbose logging
config :logger, level: :debug

# Development-specific LLM settings
config :elixir_chain, :llm,
  cache_responses: true,
  log_requests: true

# Enable code reloading for development
config :elixir_chain, :code_reloader, true
