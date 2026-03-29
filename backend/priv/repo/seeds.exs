# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# This is a starter template - add your seed data here as you build your application.

alias SertantaiCompliance.Auth.{Organization, User}

IO.puts("\n🌱 Seeding SertantaiCompliance database...")

# ========================================
# EXAMPLE: Create organization and users
# ========================================
# Uncomment and modify this example code to seed your development database

# org_id_string = Ash.UUID.generate()
# {:ok, org_id_binary} = Ecto.UUID.dump(org_id_string)
# now = DateTime.utc_now() |> DateTime.truncate(:second)
#
# {:ok, %Postgrex.Result{rows: [org_row]}} =
#   Ecto.Adapters.SQL.query(
#     SertantaiCompliance.Repo,
#     "INSERT INTO organizations (id, name, slug, inserted_at, updated_at)
#    VALUES ($1, $2, $3, $4, $5)
#    ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name
#    RETURNING *",
#     [org_id_binary, "Demo Organization", "demo-org", now, now]
#   )
#
# org_id = Enum.at(org_row, 0)
#
# user_id_string = Ash.UUID.generate()
# {:ok, user_id_binary} = Ecto.UUID.dump(user_id_string)
#
# {:ok, %Postgrex.Result{rows: [user_row]}} =
#   Ecto.Adapters.SQL.query(
#     SertantaiCompliance.Repo,
#     "INSERT INTO users (id, email, name, organization_id, inserted_at, updated_at)
#    VALUES ($1, $2, $3, $4, $5, $6)
#    ON CONFLICT (id) DO UPDATE SET email = EXCLUDED.email
#    RETURNING *",
#     [user_id_binary, "user@example.com", "Demo User", org_id, now, now]
#   )
#
# IO.puts("✓ Created demo organization and user")

IO.puts("\n✅ Seed script completed!")
IO.puts("Add your seed data above as you develop your application.\n")
