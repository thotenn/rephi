# Production image: the Phoenix release plus the frontends it serves
# (priv/static/apps). The API documentation is built from the code at runtime.
#
#     docker build -t rephi .
#     docker run --rm -p 4000:4000 \
#       -e DATABASE_URL=ecto://USER:PASS@HOST/DATABASE \
#       -e SECRET_KEY_BASE=... -e GUARDIAN_SECRET_KEY=... -e PHX_HOST=api.example.com \
#       rephi
#
# Database tasks, from the same image (seeding needs ADMIN_EMAIL / ADMIN_PASSWORD
# the first time):
#
#     docker run --rm -e DATABASE_URL=... -e SECRET_KEY_BASE=... ... rephi bin/migrate
#     docker run --rm -e ... -e ADMIN_EMAIL=... -e ADMIN_PASSWORD=... rephi bin/seed
#
# Every variable is described in .env.example. The versions below follow
# .tool-versions; images:
#
#   - https://hub.docker.com/r/hexpm/elixir/tags (builder)
#   - https://hub.docker.com/_/debian/tags (runner, same Debian as the builder)
#   - https://hub.docker.com/_/node/tags (frontends)

ARG ELIXIR_VERSION=1.20.5
ARG OTP_VERSION=29.1.2
ARG DEBIAN_VERSION=trixie-20261104-slim
ARG NODE_VERSION=26.13.1

ARG BUILDER_IMAGE="docker.io/hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="docker.io/debian:${DEBIAN_VERSION}"
ARG NODE_IMAGE="docker.io/node:${NODE_VERSION}-trixie-slim"

# --- Frontends: shared-components and every app into priv/static/apps --------
FROM ${NODE_IMAGE} AS frontends

WORKDIR /app

# Node.js 25+ no longer ships Corepack; Yarn's version comes from
# "packageManager" in package.json.
ENV COREPACK_ENABLE_DOWNLOAD_PROMPT=0
RUN npm install --global corepack && corepack enable

COPY package.json yarn.lock .yarnrc.yml ./
COPY apps apps
COPY packages packages
COPY scripts scripts
RUN yarn install --immutable

# A build of a Vite app calls the API on the origin that serves it (`/api`,
# `/socket`) unless VITE_API_URL / VITE_WS_URL say otherwise, so no variable is
# needed here.
RUN yarn shared:build && yarn build

# --- Release ------------------------------------------------------------------
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

# Compile-time configuration first, so a change to it recompiles the deps.
COPY config/config.exs config/dotenv.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

COPY priv priv
COPY lib lib
RUN mix compile

# Build-time artifacts the release serves.
COPY --from=frontends /app/priv/static/apps priv/static/apps

# Changes to config/runtime.exs don't require recompiling the code
COPY config/runtime.exs config/

COPY rel rel
RUN mix release

# --- Runtime image -------------------------------------------------------------
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

# If using an environment that doesn't automatically reap zombie processes, it is
# advised to add an init process such as tini via `apt-get install`
# above and adding an entrypoint. See https://github.com/krallin/tini for details
# ENTRYPOINT ["/tini", "--"]

CMD ["/app/bin/server"]
