defmodule Mix.Tasks.Changes.Detect do
  @shortdoc "Detect legal changes affecting orgs and record them in the change feed"

  @moduledoc """
  Runs `SertantaiCompliance.Sync.ChangeDetector` once, as the daily job does.

      mix changes.detect             # diff against the last run, record events
      mix changes.detect --baseline  # record current state only, no events

  The first ever run records the baseline automatically.
  """

  use Mix.Task

  alias SertantaiCompliance.Sync.ChangeDetector

  @impl Mix.Task
  def run(argv) do
    {opts, _} = OptionParser.parse!(argv, strict: [baseline: :boolean])
    Mix.Task.run("app.start")

    {:ok, summary} = ChangeDetector.run(baseline: opts[:baseline] == true)

    Mix.shell().info("""
    Change detection #{if summary.baseline, do: "baseline recorded", else: "complete"}
      watched laws: #{summary.watched}
      changed laws: #{summary.changes}
      events by org: #{inspect(summary.events, pretty: true)}
    """)
  end
end
