defmodule RephiWeb.Schemas.ErrorResponse do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(
    %{
      description: "Envelope of every error that is not a validation error",
      type: :object,
      properties: %{
        errors: %Schema{
          type: :object,
          properties: %{
            detail: %Schema{type: :string, description: "Human readable error message"}
          },
          required: [:detail]
        }
      },
      required: [:errors],
      example: %{errors: %{detail: "Not Found"}}
    },
    struct?: false
  )
end

defmodule RephiWeb.Schemas.ValidationErrors do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(
    %{
      description: "Envelope of a 422: one list of messages per invalid field",
      type: :object,
      properties: %{
        errors: %Schema{
          type: :object,
          description: "Validation error messages keyed by field",
          additionalProperties: %Schema{type: :array, items: %Schema{type: :string}}
        }
      },
      required: [:errors],
      example: %{
        errors: %{
          email: ["can't be blank"],
          password: ["should be at least 8 character(s)"]
        }
      }
    },
    struct?: false
  )
end

defmodule RephiWeb.Schemas.PageMeta do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(
    %{
      description: "Where a page sits in the whole list",
      type: :object,
      properties: %{
        page: %Schema{type: :integer, description: "Current page, from 1"},
        page_size: %Schema{type: :integer, description: "Entries per page (at most 100)"},
        total: %Schema{type: :integer, description: "Entries in the whole list"},
        total_pages: %Schema{type: :integer, description: "Number of pages"}
      },
      required: [:page, :page_size, :total, :total_pages],
      example: %{page: 1, page_size: 50, total: 3, total_pages: 1}
    },
    struct?: false
  )
end

defmodule RephiWeb.Schemas.Grant do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(
    %{
      description: "A role or a permission, by id, name and slug",
      type: :object,
      properties: %{
        id: %Schema{type: :integer},
        name: %Schema{type: :string},
        slug: %Schema{type: :string}
      },
      required: [:id, :name, :slug],
      example: %{id: 1, name: "Administrator", slug: "admin"}
    },
    struct?: false
  )
end

defmodule RephiWeb.Schemas.GrantWithDescription do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(
    %{
      description: "A role or a permission with its description",
      type: :object,
      properties: %{
        id: %Schema{type: :integer},
        name: %Schema{type: :string},
        slug: %Schema{type: :string},
        description: %Schema{type: :string, nullable: true}
      },
      required: [:id, :name, :slug, :description],
      example: %{id: 5, name: "View Roles", slug: "roles:view", description: "View roles"}
    },
    struct?: false
  )
end

defmodule RephiWeb.Schemas.AssignmentNotes do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(
    %{
      description: "Optional notes kept with an assignment",
      type: :object,
      properties: %{
        notes: %Schema{type: :string, maxLength: 2000}
      },
      example: %{notes: "Covers for the team lead in March"}
    },
    struct?: false
  )
end
