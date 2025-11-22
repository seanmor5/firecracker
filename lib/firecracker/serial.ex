defmodule Firecracker.Serial do
  @moduledoc """
  Represents a serial console device configuration for Firecracker.

  The serial console allows the guest to write kernel logs and serial output
  to a file or named pipe on the host. This is especially useful for debugging
  and capturing boot logs.

  ## Fields

    * `:output_path` - Optional. Path to a file or named pipe on the host to
      which serial output should be written

  Note: This configuration has no effect if the serial console is not also enabled
  on the guest kernel command line (e.g., `console=ttyS0`).
  """

  @pre_boot_schema NimbleOptions.new!(output_path: [type: :string, required: false])

  @post_boot_schema NimbleOptions.new!([])

  @derive {Firecracker.Model,
           pre_boot_schema: @pre_boot_schema,
           post_boot_schema: @post_boot_schema,
           endpoint: "/serial"}

  defstruct [
    :output_path,
    applied?: false
  ]

  @type t :: %__MODULE__{
          output_path: String.t() | nil,
          applied?: boolean()
        }
end
