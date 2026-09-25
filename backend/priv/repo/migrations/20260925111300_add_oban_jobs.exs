defmodule SertantaiCompliance.Repo.Migrations.AddObanJobs do
  @moduledoc """
  Oban job tables, for scheduled work such as daily change detection.

  Oban's migrations are idempotent and versioned; later Oban upgrades add a
  migration calling `Oban.Migration.up(version: N)`.
  """

  use Ecto.Migration

  def up, do: Oban.Migration.up(version: 14)

  def down, do: Oban.Migration.down(version: 1)
end
