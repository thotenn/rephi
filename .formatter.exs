[
  import_deps: [:ecto, :ecto_sql, :phoenix],
  subdirectories: ["priv/*/migrations"],
  inputs: ["*.{ex,exs}", "{config,lib,test}/**/*.{ex,exs}", "priv/*/seeds.exs"],
  locals_without_parens: [
    # Mix tasks
    rephi: 1,
    rephi: 2,

    # Plugs
    plug: 1,
    plug: 2,

    # Phoenix
    action_fallback: 1,
    render: 2,
    render: 3,
    render: 4,
    redirect: 2,
    socket: 2,
    socket: 3
  ]
]
