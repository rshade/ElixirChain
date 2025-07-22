# Build stage
FROM elixir:1.16-alpine AS build

# Install build dependencies
RUN apk add --no-cache build-base git python3

# Prepare build dir
WORKDIR /app

# Install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Set build ENV
ENV MIX_ENV=prod

# Install mix dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config

# Copy compile-time config
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

# Copy application files
COPY priv priv
COPY lib lib

# Compile and build release
RUN mix compile

# Changes to config/runtime.exs don't require recompiling the code
COPY config/runtime.exs config/

# Create release
RUN mix release

# Runtime stage
FROM alpine:3.19 AS app

# Install runtime dependencies
RUN apk add --no-cache openssl ncurses-libs libstdc++ libgcc

WORKDIR /app

# Create non-root user
RUN addgroup -g 1000 elixirchain && \
    adduser -u 1000 -G elixirchain -s /bin/sh -D elixirchain

# Copy release from build stage
COPY --from=build --chown=elixirchain:elixirchain /app/_build/prod/rel/elixir_chain ./

USER elixirchain

# Set runtime ENV
ENV HOME=/app
ENV MIX_ENV=prod
ENV PORT=4000

EXPOSE 4000

# Start the application
CMD ["bin/elixir_chain", "start"]