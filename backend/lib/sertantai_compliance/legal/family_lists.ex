defmodule SertantaiCompliance.Legal.FamilyLists do
  @moduledoc """
  Static family name lists for compliance templates.

  Extracted from sertantai-legal's Scraper.Models — these are reference
  constants, not scraper logic. Used by sync templates for Baserow
  field options (family dropdowns).
  """

  def ehs_family do
    [
      "💙 FIRE",
      "💙 FIRE: Dangerous and Explosive Substances",
      "💙 FOOD",
      "💙 HEALTH: Coronavirus",
      "💙 HEALTH: Drug & Medicine Safety",
      "💙 HEALTH: Patient Safety",
      "💙 HEALTH: Public",
      "💙 OH&S: Gas & Electrical Safety",
      "💙 OH&S: Mines & Quarries",
      "💙 OH&S: Occupational / Personal Safety",
      "💙 OH&S: Offshore Safety",
      "💙 PUBLIC",
      "💙 PUBLIC: Building Safety",
      "💙 PUBLIC: Consumer / Product Safety",
      "💙 PUBLIC: Data",
      "💙 TRANSPORT: Air Safety",
      "💙 TRANSPORT: Rail Safety",
      "💙 TRANSPORT: Road Safety",
      "💙 TRANSPORT: Maritime Safety",
      "💚 AGRICULTURE",
      "💚 AGRICULTURE: Pesticides",
      "💚 AIR QUALITY",
      "💚 ANIMALS & ANIMAL HEALTH",
      "💚 ANTARCTICA",
      "💚 BUILDINGS",
      "💚 CLIMATE CHANGE",
      "💚 ENERGY",
      "💚 ENVIRONMENTAL PROTECTION",
      "💚 FISHERIES & FISHING",
      "💚 GMOs",
      "💚 HISTORIC ENVIRONMENT",
      "💚 MARINE & RIVERINE",
      "💚 NOISE",
      "💚 NUCLEAR & RADIOLOGICAL",
      "💚 OIL & GAS - OFFSHORE - PETROLEUM",
      "💚 PLANNING & INFRASTRUCTURE",
      "💚 PLANT HEALTH",
      "💚 POLLUTION",
      "💚 TOWN & COUNTRY PLANNING",
      "💚 TRANSPORT",
      "💚 TRANSPORT: Aviation",
      "💚 TRANSPORT: Harbours & Shipping",
      "💚 TRANSPORT: Railways & Rail Transport",
      "💚 TRANSPORT: Roads & Vehicles",
      "💚 TREES: Forestry & Timber",
      "💚 WASTE",
      "💚 WATER & WASTEWATER",
      "💚 WILDLIFE & COUNTRYSIDE"
    ]
  end

  def hr_family do
    [
      "💜 HR: Employment",
      "💜 HR: Insurance / Compensation / Wages / Benefits",
      "💜 HR: Working Time"
    ]
  end
end
