defmodule Firecracker.Metrics do
  @moduledoc """
  Represents the metrics system configuration for Firecracker.

  The metrics system allows Firecracker to write JSON-formatted metrics to a
  named pipe or file on the host. Metrics are flushed either automatically or
  via the FlushMetrics action.

  ## Fields

    * `:metrics_path` - Required. Path to the named pipe or file where the
      JSON-formatted metrics are flushed
  """

  @pre_boot_schema NimbleOptions.new!(metrics_path: [type: :string, required: true])

  @post_boot_schema NimbleOptions.new!([])

  @derive {Firecracker.Model,
           pre_boot_schema: @pre_boot_schema,
           post_boot_schema: @post_boot_schema,
           endpoint: "/metrics"}

  @enforce_keys [:metrics_path]
  defstruct [
    :metrics_path,
    applied?: false
  ]

  @type t :: %__MODULE__{
          metrics_path: String.t(),
          applied?: boolean()
        }
end
