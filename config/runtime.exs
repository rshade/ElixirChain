import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere.

if config_env() == :prod do
  # Database configuration
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  config :elixir_chain, ElixirChain.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")

  # LLM API Keys
  config :elixir_chain, :openai,
    api_key: System.get_env("OPENAI_API_KEY"),
    organization: System.get_env("OPENAI_ORGANIZATION")

  config :elixir_chain, :anthropic,
    api_key: System.get_env("ANTHROPIC_API_KEY")

  # Redis configuration
  redis_url = System.get_env("REDIS_URL") || "redis://localhost:6379"
  
  config :elixir_chain, :redis,
    url: redis_url

  # Secret key base
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  config :elixir_chain, :secret_key_base, secret_key_base

  # Distributed Erlang
  if System.get_env("RELEASE_NODE") do
    config :elixir_chain,
      distributed: [
        enabled: true,
        cluster_name: String.to_atom(System.get_env("CLUSTER_NAME") || "elixir_chain"),
        node_discovery: :kubernetes
      ]
  end
end