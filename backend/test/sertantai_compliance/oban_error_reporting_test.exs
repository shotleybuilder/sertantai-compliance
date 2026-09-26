defmodule SertantaiCompliance.ObanErrorReportingTest do
  use SertantaiCompliance.DataCase, async: false
  use Oban.Testing, repo: SertantaiCompliance.Repo

  defmodule FailingWorker do
    use Oban.Worker, queue: :default
    @impl Oban.Worker
    def perform(_job), do: raise("change detection exploded")
  end

  setup do
    Sentry.Test.setup_sentry()
    :ok
  end

  # The daily ChangeDetectionWorker fails silently otherwise: the feed just
  # stays empty. Job failures must reach the error tracker.
  test "a failing background job is reported" do
    assert_raise RuntimeError, fn -> perform_job(FailingWorker, %{}) end

    assert [event] = Sentry.Test.pop_sentry_reports()
    assert %RuntimeError{message: "change detection exploded"} = event.original_exception
  end
end
