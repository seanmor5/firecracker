defmodule Firecracker.Pmem do
  @moduledoc """
  Represents a virtio-pmem (persistent memory) device configuration for Firecracker.

  Pmem devices provide a persistent memory interface backed by a file on the host.
  They can be used as root devices or additional storage devices.

  ## Fields

    * `:id` - Required. Unique identifier for this pmem device
    * `:path_on_host` - Required. Host-level path for the virtio-pmem device backing file
    * `:root_device` - Optional. Flag to make this device the root device for VM boot
    * `:read_only` - Optional. Flag to map backing file in read-only mode

  """

  @pre_boot_schema NimbleOptions.new!(
                     id: [type: :string, required: true],
                     path_on_host: [type: :string, required: true],
                     root_device: [type: :boolean, required: false],
                     read_only: [type: :boolean, required: false]
                   )

  @post_boot_schema NimbleOptions.new!([])

  @derive {Firecracker.Model,
           pre_boot_schema: @pre_boot_schema,
           post_boot_schema: @post_boot_schema,
           endpoint: "/pmem",
           id_key: :id}

  @enforce_keys [:id, :path_on_host]
  defstruct [
    :id,
    :path_on_host,
    :root_device,
    :read_only,
    applied?: false
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          path_on_host: String.t(),
          root_device: boolean() | nil,
          read_only: boolean() | nil,
          applied?: boolean()
        }
end
