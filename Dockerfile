# syntax=docker/dockerfile:1

##
## Build stage
##
FROM hexpm/elixir:1.15.7-erlang-26.2.5.10-debian-bookworm-20250929 AS build

ENV MIX_ENV=prod
WORKDIR /app

# Build dependencies (kept minimal; release itself should not need Node in prod).
RUN apt-get update && apt-get install -y --no-install-recommends \
  build-essential git curl ca-certificates \
  && rm -rf /var/lib/apt/lists/*

COPY mix.exs mix.lock ./
COPY config ./config
COPY lib ./lib
COPY rel ./rel
COPY priv ./priv
COPY assets ./assets

# Fetch + compile
RUN mix deps.get --only prod && mix deps.compile
RUN mix compile

# Build assets for production (digested)
RUN mix assets.deploy

# Release
# DATABASE_PATH + SECRET_KEY_BASE are required at runtime; we provide build-time defaults
# to make the release task happy in strict configurations.
ARG SECRET_KEY_BASE=change-me-in-production
ENV SECRET_KEY_BASE=${SECRET_KEY_BASE}
ENV DATABASE_PATH=/data/w_core.db
RUN mix release --overwrite

##
## Runtime stage
##
FROM debian:bookworm-slim AS runtime

RUN apt-get update && apt-get install -y --no-install-recommends \
  openssl ca-certificates \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=build /app/_build/prod/rel/w_core ./

ENV PHX_SERVER=true
ENV PORT=4000
ENV DATABASE_PATH=/data/w_core.db
ENV SECRET_KEY_BASE=change-me-in-production

VOLUME ["/data"]

EXPOSE 4000

CMD ["/app/bin/w_core", "start"]

