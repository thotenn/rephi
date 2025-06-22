# Rephi Installer

This package provides the `mix rephi.new` task to generate new Rephi projects.

## Installation

```bash
mix archive.install hex rephi_new
```

## Usage

```bash
mix rephi.new my_app
```

## Options

- `--app` - The OTP application name
- `--module` - The main module name

## Example

```bash
mix rephi.new blog --module BlogApp --app blog_app
```