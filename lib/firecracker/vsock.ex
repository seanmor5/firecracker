defmodule Firecracker.Vsock do
  @moduledoc """
  Configures a virtio-vsock device for host-guest communication in Firecracker.

  Virtio-vsock provides a high-performance, low-latency communication channel
  between the host and guest VM using a socket-like API. This is useful for
  secure, efficient data transfer and service communication.

  ## Fields

    * `:guest_cid` - Required. Guest context identifier (unique ID for the VM)
    * `:uds_path` - Required. UNIX domain socket path on the host for vsock communication
    * `:vsock_id` - Optional. Identifier for the vsock device

  ## Configuration Behavior

  No fields can be modified after VM starts

  ## Context IDs (CIDs)

    * Guest CID must be a positive integer unique to each VM
    * CID 0 and 1 are reserved for the hypervisor
    * CID 2 is reserved for the host
    * Guest CIDs typically start from 3

  ## Notes

    * The UNIX domain socket path must be accessible to the Firecracker process
    * Vsock provides better performance than traditional network-based communication
    * Only one vsock device can be configured per VM
    * The socket path should not already exist when starting the VM
    * Vsock is ideal for agent communication, file transfer, and microservice patterns
  """

  @pre_boot_schema NimbleOptions.new!(
                     guest_cid: [type: :pos_integer, required: true],
                     uds_path: [type: :string, required: true],
                     vsock_id: [type: :string, required: false]
                   )

  @post_boot_schema NimbleOptions.new!([])

  @derive {Firecracker.Model,
           pre_boot_schema: @pre_boot_schema,
           post_boot_schema: @post_boot_schema,
           endpoint: "/vsock"}
  @enforce_keys [:guest_cid, :uds_path]
  defstruct [
    :guest_cid,
    :uds_path,
    :vsock_id,
    # internal
    applied?: false
  ]

  @type t :: %__MODULE__{
          guest_cid: pos_integer(),
          uds_path: String.t(),
          vsock_id: String.t() | nil,
          applied?: boolean()
        }
end
