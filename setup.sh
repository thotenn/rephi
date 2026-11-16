#!/usr/bin/env bash
#
# Sets up a development environment, from a fresh clone or again after a pull:
#
#   1. checks the toolchain: Elixir and Erlang/OTP (the versions in
#      .tool-versions are the minimums), Node.js (`engines` in package.json),
#      Yarn 4 through Corepack, and that PostgreSQL answers;
#   2. writes the development secrets into .env (scripts/dev_env.exs);
#   3. `mix setup`: dependencies, database, migrations, seeds;
#   4. installs the frontend dependencies and builds shared-components and
#      every app into priv/static/apps.
#
# Safe to run again: nothing that exists is overwritten. Works from any
# directory. Every failure stops the script with its own error.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

if [ -t 1 ]; then
  BLUE=$'\033[0;34m' GREEN=$'\033[0;32m' YELLOW=$'\033[1;33m' RED=$'\033[0;31m' NC=$'\033[0m'
else
  BLUE='' GREEN='' YELLOW='' RED='' NC=''
fi

step() { printf '\n%s==>%s %s%s%s\n' "$BLUE" "$NC" "$GREEN" "$1" "$NC"; }
note() { printf '%sNote:%s %s\n' "$YELLOW" "$NC" "$1"; }
fail() { printf '%sError:%s %s\n' "$RED" "$NC" "$1" >&2; exit 1; }

# version_ge A B: true when version A >= version B (dot-separated numbers).
version_ge() {
  local IFS=.
  # shellcheck disable=SC2206
  local a=($1) b=($2) i
  for i in 0 1 2; do
    local x=${a[$i]:-0} y=${b[$i]:-0}
    if [ "$x" -gt "$y" ]; then return 0; fi
    if [ "$x" -lt "$y" ]; then return 1; fi
  done
  return 0
}

# tool_version NAME: the version of NAME in .tool-versions, if any.
tool_version() {
  awk -v tool="$1" '$1 == tool { print $2; exit }' .tool-versions 2>/dev/null || true
}

require() {
  command -v "$1" >/dev/null 2>&1 || fail "$1 is not installed. $2"
}

# Reads NAME from the environment, or else from .env (a plain NAME=value line).
setting() {
  local value="${!1:-}"
  if [ -z "$value" ] && [ -f .env ]; then
    value="$(awk -F= -v key="$1" '$1 == key || $1 == "export " key { sub(/^[^=]*=/, ""); gsub(/["'\'']/, ""); print; exit }' .env)"
  fi
  printf '%s' "${value:-$2}"
}

export MIX_ENV="${MIX_ENV:-dev}"
[ "$MIX_ENV" = "dev" ] || fail "setup.sh prepares the development environment, but MIX_ENV is $MIX_ENV."

# --- 1. Toolchain ------------------------------------------------------------

step "Checking the toolchain"

require elixir "See https://elixir-lang.org/install.html (versions in .tool-versions)."
require erl "Erlang/OTP is installed together with Elixir."
require node "See https://nodejs.org (the minimum version is in package.json, \"engines\")."

elixir_min="$(tool_version elixir | sed 's/-otp-.*//')"
elixir_version="$(elixir -e 'IO.write(System.version())')"
elixir_version="${elixir_version%%-*}"
if [ -n "$elixir_min" ] && ! version_ge "$elixir_version" "$elixir_min"; then
  fail "Elixir $elixir_min or newer is required (found $elixir_version)."
fi

otp_min="$(tool_version erlang | cut -d. -f1)"
otp_version="$(erl -noshell -eval 'io:format("~s", [erlang:system_info(otp_release)]), halt().')"
if [ -n "$otp_min" ] && [ "$otp_version" -lt "$otp_min" ]; then
  fail "Erlang/OTP $otp_min or newer is required (found $otp_version)."
fi
echo "Elixir $elixir_version, Erlang/OTP $otp_version"

node_min="$(node -p "((require('./package.json').engines || {}).node || '').replace(/[^0-9.]/g, '')")"
node_min="${node_min:-22.22.0}"
node_version="$(node -p 'process.versions.node')"
node_version="${node_version%%-*}"
version_ge "$node_version" "$node_min" || fail "Node.js $node_min or newer is required (found $node_version)."
echo "Node.js $node_version"

# Yarn comes from Corepack, pinned by "packageManager" in package.json. Node.js
# 25 and newer no longer ship Corepack.
export COREPACK_ENABLE_DOWNLOAD_PROMPT=0
yarn_major() { "$@" --version 2>/dev/null | cut -d. -f1; }
if command -v yarn >/dev/null 2>&1 && [ "$(yarn_major yarn)" = "4" ]; then
  YARN=(yarn)
elif command -v corepack >/dev/null 2>&1 && [ "$(yarn_major corepack yarn)" = "4" ]; then
  YARN=(corepack yarn)
else
  fail "Yarn 4 is required, through Corepack. Install Corepack with 'npm install -g corepack' (Node.js 25+ no longer includes it) and run 'corepack enable'."
fi
echo "Yarn $("${YARN[@]}" --version)"

db_host="$(setting DB_HOSTNAME localhost)"
if command -v pg_isready >/dev/null 2>&1; then
  pg_isready -q -h "$db_host" -p 5432 -t 5 ||
    fail "PostgreSQL is not answering on $db_host:5432. Start it, or set DB_HOSTNAME / DB_USERNAME / DB_PASSWORD in .env."
  echo "PostgreSQL on $db_host:5432"
else
  note "pg_isready not found; the database step below will report if PostgreSQL is unreachable."
fi

# --- 2. Development secrets --------------------------------------------------

step "Writing the development secrets (.env)"
elixir scripts/dev_env.exs

# --- 3. Phoenix ----------------------------------------------------------------

step "Setting up Phoenix: dependencies, database, seeds (mix setup)"
mix setup

# --- 4. Frontends --------------------------------------------------------------

step "Installing the frontend dependencies"
"${YARN[@]}" install

step "Building shared-components"
"${YARN[@]}" shared:build

step "Building the frontend apps into priv/static/apps"
"${YARN[@]}" build

# --- Done ------------------------------------------------------------------------

port="$(setting PORT 4000)"

printf '\n%sSetup complete.%s\n\n' "$GREEN" "$NC"
cat <<EOF
Start Phoenix:          mix phx.server
Example app:            http://localhost:$port/app/example/
API documentation:      http://localhost:$port/api/swagger
Frontend dev server:    ${YARN[*]} example:dev

Log in with the development administrator the seeds reported above
(admin@admin.com / password123!! unless ADMIN_EMAIL and ADMIN_PASSWORD are set).
EOF
