[
  import_deps: [:ecto, :ecto_sql, :open_api_spex, :phoenix],
  subdirectories: ["priv/*/migrations"],
  inputs: [
    "*.{ex,exs}",
    "{config,lib,test}/**/*.{ex,exs}",
    "priv/*/*.exs",
    "scripts/*.exs",
    "installer/{mix,.formatter}.exs",
    "installer/{lib,test}/**/*.{ex,exs}"
  ]
]
