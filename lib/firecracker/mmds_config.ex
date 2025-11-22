defmodule Firecracker.MmdsConfig do
  @moduledoc """
  Configures the Microvm Metadata Service (MMDS) for Firecracker virtual machines.

  MMDS provides a way to serve metadata to guest VMs through a standardized HTTP
  endpoint, similar to EC2 instance metadata service. It allows the guest to retrieve
  configuration data and credentials without additional network dependencies.

  ## Fields

    * `:network_interfaces` - Required. List of network interface IDs that can access MMDS
    * `:version` - Optional. MMDS service version (e.g., "V1", "V2")
    * `:ipv4_address` - Optional. IPv4 address for MMDS endpoint, defaults to 169.254.169.254
    * `:imds_compat` - Optional. Enable EC2 IMDS compatibility mode (responds with "text/plain" regardless of Accept header)
    * `:applied?` - Internal flag indicating whether this configuration has been applied

  ## Post-boot Behavior

  No fields can be modified after VM starts

  ## Notes

    * MMDS is accessible from within the guest VM at the specified IPv4 address
    * Only network interfaces listed in `:network_interfaces` can access MMDS
    * Version "V2" requires authentication tokens for accessing metadata
    * The default IPv4 address (169.254.169.254) matches EC2's metadata service
  """

  @pre_boot_schema NimbleOptions.new!(
                     network_interfaces: [type: {:list, :string}, required: true],
                     version: [type: :string, required: false],
                     ipv4_address: [type: :string, required: false],
                     imds_compat: [type: :boolean, required: false]
                   )

  @post_boot_schema NimbleOptions.new!([])

  @derive {Firecracker.Model,
           pre_boot_schema: @pre_boot_schema,
           post_boot_schema: @post_boot_schema,
           endpoint: "/mmds/config"}
  @enforce_keys [:network_interfaces]
  defstruct [
    :network_interfaces,
    :version,
    :ipv4_address,
    :imds_compat,
    # internal
    applied?: false
  ]

  @type t :: %__MODULE__{
          network_interfaces: [String.t()],
          version: String.t() | nil,
          ipv4_address: String.t() | nil,
          imds_compat: boolean() | nil,
          applied?: boolean()
        }
end
