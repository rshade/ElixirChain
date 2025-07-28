import Config

# General application configuration
config :elixir_chain,
  # Agent configuration
  agent: [
    max_agents: 100,
    default_timeout: 30_000,
    memory_limit: :infinity
  ],

  # LLM provider settings
  llm: [
    providers: [:openai, :anthropic, :local],
    default_provider: :openai,
    retry_attempts: 3,
    timeout: 60_000
  ],

  # Memory configuration
  memory: [
    # Start with ETS for development
    backend: :ets,
    vector_dimensions: 1536,
    max_conversation_length: 4000,
    compression_threshold: 8000
  ],

  # Tool configuration
  tools: [
    enabled: [:web_search, :calculator, :file_system],
    timeout: 30_000,
    max_concurrent: 5
  ],

  # Distributed settings
  distributed: [
    enabled: false,
    cluster_name: :elixir_chain_cluster,
    node_discovery: :manual
  ]

# Configure Elixir logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id, :agent_id, :tool]

# Import environment specific config
import_config "#{config_env()}.exs"
