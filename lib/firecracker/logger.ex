defmodule Firecracker.Logger do
  @moduledoc """
  Configures logging settings for the Firecracker virtual machine.

  This module controls the logging behavior of the Firecracker host process,
  including log levels, output destination, and formatting options.

  ## Fields

    * `:level` - Optional. Log level (e.g., "Info", "Warning", "Error")
    * `:log_path` - Optional. File path for logs. If not specified, logs to stdout
    * `:show_level` - Optional. Whether to include log level in output
    * `:show_log_origin` - Optional. Whether to include source location in logs
    * `:module` - Optional. Specific module to configure logging for

  ## Post-boot Behavior

  No fields can be modified after VM starts

  ## Log Levels

  Available log levels (from least to most verbose):
    * "Off" - No logging
    * "Error" - Only error messages
    * "Warning" - Warnings and errors
    * "Info" - Information, warnings, and errors
    * "Debug" - All log messages

  ## Notes

    * Logger configuration must be set before starting the VM
    * If `log_path` is not specified, logs are written to stdout
    * `show_log_origin` can help with debugging but may impact performance
    * The logger configuration affects the Firecracker host process, not the guest VM
  """

  @pre_boot_schema NimbleOptions.new!(
                     level: [type: :string, required: false],
                     log_path: [type: :string, required: false],
                     show_level: [type: :boolean, required: false],
                     show_log_origin: [type: :boolean, required: false],
                     module: [type: :string, required: false]
                   )

  @post_boot_schema NimbleOptions.new!([])

  @derive {Firecracker.Model,
           pre_boot_schema: @pre_boot_schema,
           post_boot_schema: @post_boot_schema,
           endpoint: "/logger"}
  defstruct [
    :level,
    :log_path,
    :show_level,
    :show_log_origin,
    :module,
    # internal
    applied?: false
  ]

  @type t :: %__MODULE__{
          level: String.t() | nil,
          log_path: String.t() | nil,
          show_level: boolean() | nil,
          show_log_origin: boolean() | nil,
          module: String.t() | nil,
          applied?: boolean()
        }
end
