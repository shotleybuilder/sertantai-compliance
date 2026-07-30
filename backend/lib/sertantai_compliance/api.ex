defmodule SertantaiCompliance.Api do
  @moduledoc """
  The main Ash Domain for SertantAI Compliance.

  This domain contains resources for compliance screening, sync, and
  change management. Reference data (legal register, articles, etc.)
  is read-only — owned by sertantai-legal, accessed via shared database.
  """

  use Ash.Domain

  resources do
    # Read-only mirrors of sertantai-legal tables (shared database)
    resource(SertantaiCompliance.Legal.LegalRegister)
    resource(SertantaiCompliance.Legal.LegalArticle)
    resource(SertantaiCompliance.Legal.AmendmentAnnotation)
    resource(SertantaiCompliance.Legal.Control)
    resource(SertantaiCompliance.Legal.ControlMapping)
    resource(SertantaiCompliance.Legal.EvidencePattern)
    resource(SertantaiCompliance.Legal.ArtefactTemplate)
    resource(SertantaiCompliance.Legal.SecondarySource)
    resource(SertantaiCompliance.Legal.SecondarySourceProvision)
    resource(SertantaiCompliance.Legal.SourceLink)

    # Customer-facing resources will be added here (read-write)
  end
end
