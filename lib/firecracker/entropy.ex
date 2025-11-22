defmodule Firecracker.Entropy do
  @moduledoc """
  Configures the entropy device for a Firecracker virtual machine.

  The entropy device provides a source of randomness to the guest VM by exposing
  a virtual hardware random number generator. This is useful for cryptographic
  operations and other applications requiring entropy.

  ## Fields

    * `:rate_limiter` - Optional. Rate limiter configuration for entropy device operations

  ## Post-boot Behavior

  No fields can be modified after VM starts

  ## Notes

    * The entropy device is optional and automatically provides /dev/hwrng to the guest
    * Rate limiting can be applied to control entropy consumption
    * Most VMs should configure an entropy device for proper randomness
    * Without rate limiting, the device provides unlimited entropy access
  """

  @pre_boot_schema NimbleOptions.new!(rate_limiter: [type: :any, required: false])

  @post_boot_schema NimbleOptions.new!([])

  @derive {Firecracker.Model,
           pre_boot_schema: @pre_boot_schema,
           post_boot_schema: @post_boot_schema,
           endpoint: "/entropy"}
  defstruct rate_limiter: nil,
            applied?: false

  @type t :: %__MODULE__{
          rate_limiter: Firecracker.RateLimiter.t() | nil,
          applied?: boolean()
        }
end
