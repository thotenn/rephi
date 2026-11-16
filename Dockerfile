ARG ELIXIR_VERSION=1.20.5
ARG OTP_VERSION=29.1.2
ARG DEBIAN_VERSION=trixie-20261104-slim
ARG NODE_VERSION=26.13.1

ARG BUILDER_IMAGE="docker.io/hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="docker.io/debian:${DEBIAN_VERSION}"
ARG NODE_IMAGE="docker.io/node:${NODE_VERSION}-trixie-slim"

FROM ${NODE_IMAGE} AS frontends

WORKDIR /app

# Node.js 25+ no longer ships Corepack.
ENV COREPACK_ENABLE_DOWNLOAD_PROMPT=0
RUN npm install --global corepack && corepack enable

COPY package.json yarn.lock .yarnrc.yml ./
COPY apps apps
COPY packages packages
COPY scripts scripts
RUN yarn install --immutable

RUN yarn shared:build && yarn build

FROM ${BUILDER_IMAGE} AS builder

RUN apt-get update \
  && apt-get install -y --no-install-recommends build-essential git \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN mix local.hex --force \
  && mix local.rebar --force

ENV MIX_ENV="prod"

COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config

# Compile-time config first, so a change to it recompiles the deps.
COPY config/config.exs config/dotenv.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

COPY priv priv
COPY lib lib
RUN mix compile

COPY --from=frontends /app/priv/static/apps priv/static/apps

# Changes to config/runtime.exs don't require recompiling the code
COPY config/runtime.exs config/

COPY rel rel
RUN mix release

FROM ${RUNNER_IMAGE} AS final

RUN apt-get update \
  && apt-get install -y --no-install-recommends libstdc++6 openssl libncurses6 locales ca-certificates \
  && rm -rf /var/lib/apt/lists/*

RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen \
  && locale-gen

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

WORKDIR "/app"
RUN chown nobody /app

ENV MIX_ENV="prod"

COPY --from=builder --chown=nobody:root /app/_build/${MIX_ENV}/rel/rephi ./

USER nobody

EXPOSE 4000

CMD ["/app/bin/server"]
