ExUnit.start()

# Ensure the application is started
Application.ensure_all_started(:elixir_chain)

# Set up any test-specific configuration
Application.put_env(:elixir_chain, :test_mode, true)
