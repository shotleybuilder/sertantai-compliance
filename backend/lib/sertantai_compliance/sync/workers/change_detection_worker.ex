defmodule SertantaiCompliance.Sync.Workers.ChangeDetectionWorker do
  @moduledoc """
  Daily change detection (see `SertantaiCompliance.Sync.ChangeDetector`),
  scheduled by `Oban.Plugins.Cron` in config.

  Unique per hour so a cron tick and a manual enqueue can't run it twice.
  """

  use Oban.Worker, queue: :default, max_attempts: 3, unique: [period: 3600]

  alias SertantaiCompliance.Sync.ChangeDetector

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    {:ok, _summary} = ChangeDetector.run(baseline: args["baseline"] == true)
    :ok
  end
end
