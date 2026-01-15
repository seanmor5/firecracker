defmodule Firecracker.NetworkInterface do
  @moduledoc """
  Configures network interfaces for a Firecracker virtual machine.

  This module manages virtual network interfaces that connect the VM to the host
  network, allowing configuration of MAC addresses, rate limiting, and device naming.

  ## Fields

    * `:iface_id` - Required. Unique identifier for the network interface
    * `:host_dev_name` - Required. Name of the network device on the host system
    * `:guest_mac` - Optional. MAC address for the interface within the guest VM
    * `:rx_rate_limiter` - Optional. Rate limiter for incoming network traffic
    * `:tx_rate_limiter` - Optional. Rate limiter for outgoing network traffic
    * `:applied?` - Internal flag indicating whether this configuration has been applied

  ## Post-boot Behavior

  The following fields can be modified after VM starts:
    * `:iface_id` - Required to identify which interface to modify
    * `:rx_rate_limiter` - Rate limiter for incoming traffic
    * `:tx_rate_limiter` - Rate limiter for outgoing traffic

  ## Notes

    * Interface IDs must be unique within a VM configuration
    * The host device must exist before attaching it to the VM
    * Guest MAC addresses should be generated to avoid conflicts
    * Rate limiters help control network bandwidth usage
    * TAP devices are commonly used as the host network device
  """

  @pre_boot_schema NimbleOptions.new!(
                     iface_id: [type: :string, required: true],
                     host_dev_name: [type: :string, required: true],
                     guest_mac: [type: :string, required: false],
                     rx_rate_limiter: [type: :any, required: false],
                     tx_rate_limiter: [type: :any, required: false]
                   )

  @post_boot_schema NimbleOptions.new!(
                      iface_id: [type: :string, required: true],
                      rx_rate_limiter: [type: :any, required: false],
                      tx_rate_limiter: [type: :any, required: false]
                    )

  @derive {Firecracker.Model,
           pre_boot_schema: @pre_boot_schema,
           post_boot_schema: @post_boot_schema,
           endpoint: "/network-interfaces",
           id_key: :iface_id}
  @enforce_keys [
    :host_dev_name,
    :iface_id
  ]
  defstruct [
    # external
    :guest_mac,
    :host_dev_name,
    :iface_id,
    :rx_rate_limiter,
    :tx_rate_limiter,
    # internal
    applied?: false
  ]

  @type t :: %__MODULE__{
          guest_mac: String.t() | nil,
          host_dev_name: String.t(),
          iface_id: String.t(),
          rx_rate_limiter: Firecracker.RateLimiter.t() | nil,
          tx_rate_limiter: Firecracker.RateLimiter.t() | nil,
          applied?: boolean()
        }
end
