defmodule SertantaiCompliance.Sync do
  @moduledoc """
  Ash Domain for the Subscription & Sync Service.

  Manages organisation entitlements (what they can sync), sync profiles
  (user-curated filters within entitlement bounds), and sync configurations
  (provider connections for pushing data to external tools like Baserow).
  """

  use Ash.Domain

  resources do
    resource(SertantaiCompliance.Sync.Organization)
    resource(SertantaiCompliance.Sync.OrgEntitlement)
    resource(SertantaiCompliance.Sync.SyncProfile)
    resource(SertantaiCompliance.Sync.SyncConfiguration)
    resource(SertantaiCompliance.Sync.SyncJob)
    resource(SertantaiCompliance.Sync.SyncRowMapping)
    resource(SertantaiCompliance.Sync.OrgApplicability)
    resource(SertantaiCompliance.Sync.OrgSecondaryApplicability)
    resource(SertantaiCompliance.Sync.OrgScreeningProfile)
    resource(SertantaiCompliance.Sync.ApplicabilityEvent)
  end
end
