defmodule Mix.Tasks.Rephi.Gen.Frontend do
  @shortdoc "Generates a new frontend application"
  @moduledoc """
  Generates a new frontend application based on the example app.

  ## Usage

      mix rephi.gen.frontend APP_NAME

  ## Examples

      mix rephi.gen.frontend dashboard
      mix rephi.gen.frontend admin_panel

  This will:
  1. Copy the example app to apps/APP_NAME
  2. Update all configuration files with the new app name
  3. Add a route in the Phoenix router
  4. Update the shared components env.ts file
  5. Add workspace scripts to the root package.json
  """

  use Mix.Task
  require Logger

  @impl Mix.Task
  def run([app_name]) do
    app_name = String.downcase(app_name)

    if not valid_app_name?(app_name) do
      Mix.raise("Invalid app name. Use only lowercase letters, numbers, and underscores.")
    end

    Mix.shell().info("🚀 Generating new frontend app: #{app_name}")

    # Paths
    source_path = Path.join(["apps", "example"])
    target_path = Path.join(["apps", app_name])

    # Check if example app exists
    if not File.exists?(source_path) do
      Mix.raise("Example app not found at #{source_path}. Please ensure the example app exists.")
    end

    # Check if target already exists
    if File.exists?(target_path) do
      Mix.raise("App #{app_name} already exists at #{target_path}")
    end

    # Step 1: Copy example app
    Mix.shell().info("📁 Copying example app...")
    File.cp_r!(source_path, target_path)

    # Step 2: Update package.json
    update_app_package_json(target_path, app_name)

    # Step 3: Update vite.config.ts
    update_vite_config(target_path, app_name)

    # Step 4: Update router.tsx
    update_router_config(target_path, app_name)

    # Step 5: Update CLAUDE.md
    update_claude_md(target_path, app_name)

    # Step 6: Update Phoenix router
    update_phoenix_router(app_name)

    # Step 7: Update shared components env.ts
    update_shared_env(app_name)

    # Step 8: Update root package.json with workspace scripts
    update_root_package_json(app_name)

    # Step 9: Clean up build artifacts
    clean_build_artifacts(target_path)

    Mix.shell().info("""

    ✅ Frontend app '#{app_name}' created successfully!

    Next steps:
    1. Run 'yarn install' to install dependencies
    2. Run 'yarn #{app_name}:dev' to start the development server
    3. Run 'yarn build' to build all apps including the new one
    4. Access your app at http://localhost:4000/app/#{app_name}

    The app is configured with:
    - Route: /app/#{app_name}
    - Development port: #{get_next_port()}
    - Basename: /app/#{app_name}
    """)
  end

  def run(_) do
    Mix.raise("Invalid arguments. Usage: mix rephi.gen.frontend APP_NAME")
  end

  defp valid_app_name?(name) do
    Regex.match?(~r/^[a-z][a-z0-9_]*$/, name)
  end

  defp update_app_package_json(app_path, app_name) do
    package_json_path = Path.join(app_path, "package.json")

    content =
      File.read!(package_json_path)
      |> String.replace("rephi-example", "rephi-#{app_name}")
      |> String.replace("Rephi Example App", "Rephi #{String.capitalize(app_name)} App")

    File.write!(package_json_path, content)
    Mix.shell().info("✓ Updated #{app_name}/package.json")
  end

  defp update_vite_config(app_path, app_name) do
    vite_config_path = Path.join(app_path, "vite.config.ts")

    content =
      File.read!(vite_config_path)
      |> String.replace("env.APPS.example", "env.APPS.#{app_name}")

    File.write!(vite_config_path, content)
    Mix.shell().info("✓ Updated #{app_name}/vite.config.ts")
  end

  defp update_router_config(app_path, app_name) do
    router_path = Path.join([app_path, "src", "router.tsx"])

    content =
      File.read!(router_path)
      |> String.replace("env.APPS.example", "env.APPS.#{app_name}")

    File.write!(router_path, content)
    Mix.shell().info("✓ Updated #{app_name}/src/router.tsx")
  end

  defp update_claude_md(app_path, app_name) do
    claude_md_path = Path.join(app_path, "CLAUDE.md")

    if File.exists?(claude_md_path) do
      content =
        File.read!(claude_md_path)
        |> String.replace("example", app_name)
        |> String.replace("Example", String.capitalize(app_name))

      File.write!(claude_md_path, content)
      Mix.shell().info("✓ Updated #{app_name}/CLAUDE.md")
    end
  end

  defp update_phoenix_router(app_name) do
    router_path = Path.join(["lib", "rephi_web", "router.ex"])
    content = File.read!(router_path)

    # Find the line with the example forward
    lines = String.split(content, "\n")

    # Find the index where we should insert the new route
    insert_index =
      Enum.find_index(lines, fn line ->
        String.contains?(
          line,
          "forward \"/example\", RephiWeb.Plugs.FrontendAppPlug, app: \"example\""
        )
      end)

    if insert_index do
      # Insert the new route after the example route
      new_route =
        "    forward \"/#{app_name}\", RephiWeb.Plugs.FrontendAppPlug, app: \"#{app_name}\""

      updated_lines = List.insert_at(lines, insert_index + 1, new_route)

      File.write!(router_path, Enum.join(updated_lines, "\n"))
      Mix.shell().info("✓ Added route to Phoenix router")
    else
      Mix.shell().warn("⚠️  Could not find example route in router.ex. Please add manually:")

      Mix.shell().info(
        "    forward \"/#{app_name}\", RephiWeb.Plugs.FrontendAppPlug, app: \"#{app_name}\""
      )
    end
  end

  defp update_shared_env(app_name) do
    env_path = Path.join(["packages", "shared-components", "src", "env.ts"])
    content = File.read!(env_path)

    # Simple approach: find the line that closes the example app config
    # and insert the new app config after it
    if String.contains?(content, "example: {") do
      port = get_next_port()

      # Create the new app config
      new_app_config =
        ",\n    #{app_name}: {\n" <>
          "      basename: \"/app/#{app_name}\",\n" <>
          "      settings: {\n" <>
          "        port: import.meta.env.VITE_#{String.upcase(app_name)}_PORT || '#{port}'\n" <>
          "      }\n" <>
          "    }"

      # Find and replace pattern - insert after the example closing brace
      # Look for the pattern of example's closing }
      updated_content =
        if Regex.match?(~r/example:\s*{[^}]+}\s*}/ms, content) do
          # Insert after the closing brace of example
          String.replace(content, ~r/(example:\s*{[^}]+})\s*}/ms, "\\1}#{new_app_config}")
        else
          # Fallback: manual instruction
          Mix.shell().warn(
            "⚠️  Could not automatically update env.ts. Please add manually after the example config:"
          )

          Mix.shell().info(new_app_config)
          content
        end

      if updated_content != content do
        File.write!(env_path, updated_content)
        Mix.shell().info("✓ Updated shared-components env.ts")
      end
    else
      Mix.shell().warn(
        "⚠️  Could not find APPS object in env.ts. Please add the app configuration manually."
      )
    end
  end

  defp update_root_package_json(app_name) do
    package_json_path = "package.json"
    content = File.read!(package_json_path)

    # Parse JSON manually to preserve formatting
    lines = String.split(content, "\n")

    # Find where to insert new scripts
    scripts_index =
      Enum.find_index(lines, fn line ->
        String.contains?(line, "\"shared:build\":")
      end)

    if scripts_index do
      # Add new scripts after shared:build
      new_scripts = [
        "    \"#{app_name}:dev\": \"yarn workspace rephi-#{app_name} dev\",",
        "    \"#{app_name}:build\": \"yarn workspace rephi-#{app_name} build\","
      ]

      # Insert with proper comma handling
      updated_lines =
        lines
        |> List.update_at(scripts_index, fn line ->
          String.replace(line, "\"", "\"") <> ","
        end)
        |> List.insert_at(scripts_index + 1, Enum.join(new_scripts, "\n"))

      File.write!(package_json_path, Enum.join(updated_lines, "\n"))
      Mix.shell().info("✓ Updated root package.json")
    else
      Mix.shell().warn("⚠️  Could not update root package.json. Please add scripts manually.")
    end
  end

  defp clean_build_artifacts(app_path) do
    # Remove dist folder if it exists
    dist_path = Path.join(app_path, "dist")

    if File.exists?(dist_path) do
      File.rm_rf!(dist_path)
    end

    # Remove node_modules if it exists
    node_modules_path = Path.join(app_path, "node_modules")

    if File.exists?(node_modules_path) do
      File.rm_rf!(node_modules_path)
    end

    Mix.shell().info("✓ Cleaned build artifacts")
  end

  defp get_next_port do
    # Read env.ts to find the highest port number
    env_path = Path.join(["packages", "shared-components", "src", "env.ts"])
    content = File.read!(env_path)

    # Extract all port numbers
    ports =
      Regex.scan(~r/port:\s*(\d+)/, content)
      |> Enum.map(fn [_, port] -> String.to_integer(port) end)
      |> Enum.sort()

    # Return next available port
    case ports do
      [] -> 5010
      list -> List.last(list) + 1
    end
  end
end
