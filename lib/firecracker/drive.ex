defmodule Firecracker.Drive do
  @moduledoc """
  Represents a disk drive configuration for a Firecracker virtual machine.

  This module configures block devices that can be attached to a VM, including
  root filesystems and additional storage devices. Drives can be configured with
  various options for caching, rate limiting, and access modes.

  ## Fields

    * `:drive_id` - Required. Unique identifier for the drive
    * `:is_root_device` - Required. Whether this drive contains the root filesystem
    * `:path_on_host` - Optional. Path to the drive file on the host filesystem
    * `:partuuid` - Optional. Partition UUID to reference a specific drive partition
    * `:cache_type` - Optional. Caching strategy (e.g., "unsafe", "writethrough")
    * `:is_read_only` - Optional. Whether the drive should be mounted read-only
    * `:rate_limiter` - Optional. I/O rate limiter configuration
    * `:io_engine` - Optional. I/O engine to use (e.g., "sync", "async")
    * `:socket` - Optional. UNIX socket path for vhost-user backed drives

  ## Post-boot Behavior

  Only `:drive_id` and `:path_on_host` can be modified after VM starts

  ## Notes

    * At least one drive must be configured as the root device
    * Drive IDs must be unique within a VM configuration
    * Rate limiters can throttle I/O operations and bandwidth
    * For block devices, use `partuuid` instead of `path_on_host`
  """

  @pre_boot_schema NimbleOptions.new!(
                     drive_id: [type: :string, required: true],
                     is_root_device: [type: :boolean, required: true],
                     path_on_host: [type: :string, required: false],
                     partuuid: [type: :string, required: false],
                     cache_type: [type: :string, required: false],
                     is_read_only: [type: :boolean, required: false],
                     rate_limiter: [type: :any, required: false],
                     io_engine: [type: :string, required: false],
                     socket: [type: :string, required: false]
                   )

  @post_boot_schema NimbleOptions.new!(
                      drive_id: [type: :string, required: false],
                      path_on_host: [type: :string, required: false],
                      rate_limiter: [type: :any, required: false]
                    )

  @derive {Firecracker.Model,
           pre_boot_schema: @pre_boot_schema,
           post_boot_schema: @post_boot_schema,
           endpoint: "/drives",
           id_key: :drive_id}
  @enforce_keys [:drive_id, :is_root_device]
  defstruct [
    # external
    :drive_id,
    :partuuid,
    :is_root_device,
    :cache_type,
    :is_read_only,
    :path_on_host,
    :rate_limiter,
    :io_engine,
    :socket,
    # internal
    applied?: false
  ]

  @type t :: %__MODULE__{
          drive_id: String.t(),
          partuuid: String.t() | nil,
          is_root_device: boolean(),
          cache_type: String.t() | nil,
          is_read_only: boolean() | nil,
          path_on_host: String.t() | nil,
          rate_limiter: Firecracker.RateLimiter.t() | nil,
          io_engine: String.t() | nil,
          socket: String.t() | nil,
          applied?: boolean()
        }
end
