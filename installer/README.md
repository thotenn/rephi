# Rephi installer

The `mix rephi.new` task, which creates a new project from the Rephi template. It is a Mix
archive built from this directory; it is not published on Hex.

## Installation

```bash
mix archive.install github thotenn/rephi --sparse installer
```

`branch NAME`, `tag NAME` or `ref SHA` after the repository install another version
(`mix help archive.install`). From a clone, while working on the installer:

```bash
cd installer
mix archive.build
mix archive.install rephi_new-*.ez
```

## Usage

```bash
mix rephi.new acme_hub
cd acme_hub
./setup.sh
mix phx.server
```

`mix rephi.new PATH` creates the project in `PATH` (which must not exist), named after its last
segment. It:

1. validates the names and the path before creating anything;
2. clones the template into a temporary directory next to `PATH`;
3. renames the application and its modules (`rephi` -> `acme_hub`, `Rephi` -> `AcmeHub`) as whole
   names, in code, configuration, seeds, migrations, tests and docs, and in file names
   (`lib/acme_hub_web/...`). URLs, the `mix rephi.*` task names (the frontend generator keeps
   its name, like `mix phx.gen.*`) and the npm names of the frontend workspaces are kept;
4. replaces the committed development and test secrets (`secret_key_base`, the Guardian signing
   key) and both signing salts with new random values;
5. writes a README, runs `mix deps.get` and `mix format`, and creates a Git repository on `main`
   with an initial commit;
6. moves the result to `PATH`. If any step fails, nothing is left behind.

## Options

- `--app` - the OTP application name (lowercase letters, digits and `_`, starting with a letter)
- `--module` - the base module name (default: the camelized application name)
- `--no-install` - skip `mix deps.get` and `mix format`
- `--no-git` - skip the Git repository
- `--from` - the template: a Git URL or a local clone (default: this repository on GitHub)
- `--branch` - the template's branch or tag

```bash
mix rephi.new ~/code/hub --app acme_hub --module AcmeHub
```

## Development

```bash
mix format --check-formatted
mix compile --warnings-as-errors
mix test            # includes generating a project from this checkout's committed HEAD
```

Bump `@version` in `mix.exs` with every change.
