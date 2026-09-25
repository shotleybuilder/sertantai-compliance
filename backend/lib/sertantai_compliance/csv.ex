defmodule SertantaiCompliance.CSV do
  @moduledoc "RFC 4180 CSV (comma separated, double-quote escaped), via NimbleCSV."

  NimbleCSV.define(__MODULE__.Parser, separator: ",", escape: "\"")

  defdelegate dump_to_iodata(rows), to: __MODULE__.Parser
  defdelegate parse_string(string), to: __MODULE__.Parser
  defdelegate parse_string(string, opts), to: __MODULE__.Parser
end
