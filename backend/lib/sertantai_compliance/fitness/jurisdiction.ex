defmodule SertantaiCompliance.Fitness.Jurisdiction do
  @moduledoc """
  Categorical jurisdiction exclusion for devolved legislation.

  A law made by a devolved legislature or executive applies only in that
  nation, whatever its expression tree says: a Northern Ireland Statutory
  Rule can't apply to an org with no presence in Northern Ireland. The law's
  type code (the middle of `UK_<type>_<year>_<number>`) is authoritative for
  this, whereas trees and `geo_extent` can be wrong (e.g. 16 `nisr` laws have
  `geo_extent = UK`; trees let place types such as `premises` stand in for
  jurisdiction).

  This is one of the few categorical exclusions (see the prefer-inclusion
  principle in `ApplicabilityEvaluator`). An org with no jurisdiction in its
  profile is never excluded: unknown facts don't exclude.
  """

  @devolved_types %{
    # Northern Ireland: Statutory Rules, Orders in Council, Acts of the
    # (pre-1972) Parliament and of the Assembly
    "nisr" => "northern_ireland",
    "nisi" => "northern_ireland",
    "nisro" => "northern_ireland",
    "apni" => "northern_ireland",
    "nia" => "northern_ireland",
    "mnia" => "northern_ireland",
    # Scotland: Acts of the Scottish Parliament, Scottish SIs
    "asp" => "scotland",
    "ssi" => "scotland",
    "sdsi" => "scotland",
    # Wales: Acts of Senedd Cymru / the Assembly, Measures, Welsh SIs
    "asc" => "wales",
    "anaw" => "wales",
    "mwa" => "wales",
    "wsi" => "wales"
  }

  # Jurisdiction codes that include each nation (the nation or a parent).
  @covering %{
    "northern_ireland" => ~w(northern_ireland united_kingdom),
    "scotland" => ~w(scotland great_britain united_kingdom),
    "wales" => ~w(wales england_and_wales great_britain united_kingdom)
  }

  @jurisdictions ~w(england wales scotland northern_ireland england_and_wales great_britain
                    united_kingdom)

  @doc """
  The nation a devolved law is confined to, from its name, or nil.

      iex> SertantaiCompliance.Fitness.Jurisdiction.devolved_nation("UK_nisr_1997_195")
      "northern_ireland"
      iex> SertantaiCompliance.Fitness.Jurisdiction.devolved_nation("UK_uksi_1999_3242")
      nil
  """
  @spec devolved_nation(String.t()) :: String.t() | nil
  def devolved_nation(law_name) do
    case String.split(law_name, "_", parts: 3) do
      ["UK", type, _rest] -> Map.get(@devolved_types, type)
      _ -> nil
    end
  end

  @doc """
  The nation `law_name` is confined to if the org's territorial codes don't
  include it, otherwise nil. Place types in the territorial dimension (e.g.
  premises) are ignored; an org with no jurisdiction codes is never excluded.
  """
  @spec excluded_nation(String.t(), [String.t()]) :: String.t() | nil
  def excluded_nation(law_name, territorial_codes) do
    org_jurisdictions = Enum.filter(territorial_codes, &(&1 in @jurisdictions))

    with nation when nation != nil <- devolved_nation(law_name),
         [_ | _] <- org_jurisdictions,
         false <- Enum.any?(org_jurisdictions, &(&1 in Map.fetch!(@covering, nation))) do
      nation
    else
      _ -> nil
    end
  end
end
