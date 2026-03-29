defmodule SertantaiCompliance.Repo do
  use AshPostgres.Repo,
    otp_app: :sertantai_compliance

  def installed_extensions do
    ["uuid-ossp", "citext", "ash-functions"]
  end

  def min_pg_version do
    %Version{major: 15, minor: 0, patch: 0}
  end
end
