defmodule Mix.Tasks.Screener.Benchmark do
  @shortdoc "Compare a screener run with an org's legacy legal register"

  @moduledoc """
  Screens an organisation's profile and compares the result with its legacy
  register, attributing a probable cause to every disagreement.

      mix screener.benchmark --org <uuid> --name qq [--label reviewed]
                             [--profile-file priv/benchmarks/qq/profile_reviewed.json]
                             [--snapshot-reference]

  Options:

    * `--org` — organisation UUID (required)
    * `--name` — benchmark name; files live in `priv/benchmarks/<name>/` (required)
    * `--label` — run label, e.g. `reviewed` or `as_found` (default: `saved`)
    * `--profile-file` — profile JSON to screen instead of the org's saved profile
    * `--snapshot-reference` — (re)write `legacy_register.csv` from
      org_applicabilities before running; otherwise the existing snapshot is
      used, so results don't drift with the database

  Output goes to `priv/benchmarks/<name>/runs/<date>-<label>/` (triage.csv,
  summary.json, summary.md) and is compared with the previous run of the same
  label.
  """

  use Mix.Task

  alias SertantaiCompliance.Fitness.Benchmark
  alias SertantaiCompliance.Fitness.ProfileCheck
  alias SertantaiCompliance.Sync.OrgScreeningProfile

  @switches [
    org: :string,
    name: :string,
    label: :string,
    profile_file: :string,
    snapshot_reference: :boolean
  ]

  @impl Mix.Task
  def run(argv) do
    {opts, _args} = OptionParser.parse!(argv, strict: @switches)
    org = opts[:org] || Mix.raise("--org is required")
    name = opts[:name] || Mix.raise("--name is required")
    label = opts[:label] || "saved"

    Mix.Task.run("app.start")
    Logger.configure(level: :warning)

    base = Path.join(["priv", "benchmarks", name])
    reference_path = Path.join(base, "legacy_register.csv")

    if opts[:snapshot_reference] || not File.exists?(reference_path) do
      rows = Benchmark.snapshot_reference(org)
      Benchmark.write_reference!(rows, reference_path)
      Mix.shell().info("Wrote reference snapshot: #{reference_path} (#{length(rows)} laws)")
    end

    reference = Benchmark.read_reference!(reference_path)
    {profile, profile_source} = load_profile(org, opts[:profile_file])

    runs_dir = Path.join(base, "runs")
    previous = previous_summary(runs_dir, label)
    run_at = DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601()
    out_dir = Path.join(runs_dir, "#{Date.utc_today()}-#{label}")

    result = Benchmark.run(reference, profile)

    meta = %{
      name: name,
      label: label,
      org: org,
      run_at: run_at,
      profile_source: profile_source,
      reference: reference_path,
      previous: previous
    }

    Benchmark.write!(result, out_dir, Map.delete(meta, :previous))
    File.write!(Path.join(out_dir, "summary.md"), Benchmark.markdown(result.summary, meta))

    Mix.shell().info(Benchmark.markdown(result.summary, meta))
    Mix.shell().info("Wrote #{out_dir}/{triage.csv,summary.json,summary.md}")
  end

  defp load_profile(_org, path) when is_binary(path) do
    {Jason.decode!(File.read!(path)), path}
  end

  defp load_profile(org, nil) do
    case OrgScreeningProfile.by_organization(org) do
      {:ok, profile} ->
        fields = profile |> Map.from_struct() |> Map.take(ProfileCheck.profile_fields())
        {fields, "saved profile (updated #{profile.updated_at})"}

      _ ->
        Mix.raise("Org #{org} has no screening profile; pass --profile-file")
    end
  end

  # Most recent earlier run with the same label, if any.
  defp previous_summary(runs_dir, label) do
    runs_dir
    |> Path.join("*-#{label}/summary.json")
    |> Path.wildcard()
    |> Enum.sort()
    |> List.last()
    |> case do
      nil -> nil
      path -> path |> File.read!() |> Jason.decode!()
    end
  end
end
