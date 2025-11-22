defmodule Firecracker.BootSource do
  @moduledoc """
  Defines the boot source configuration for a Firecracker virtual machine.

  The boot source specifies the kernel image and optional initial ramdisk (initrd)
  required to start a Firecracker VM. This configuration must be applied before
  starting the VM.

  ## Fields

    * `:kernel_image_path` - Required. Path to the kernel image file
    * `:boot_args` - Optional. Command line arguments passed to the kernel at boot
    * `:initrd_path` - Optional. Path to the initial ramdisk file

  ## Post-boot Behavior

  No fields can be modified after VM starts

  ## Notes

    * The boot source must be configured before starting the VM
    * The kernel image path is mandatory as it's required for VM startup
    * All paths should be absolute paths on the host system
  """

  @pre_boot_schema NimbleOptions.new!(
                     kernel_image_path: [type: :string, required: true],
                     boot_args: [type: :string, required: false],
                     initrd_path: [type: :string, required: false]
                   )
  @post_boot_schema NimbleOptions.new!([])

  @derive {Firecracker.Model,
           pre_boot_schema: @pre_boot_schema,
           post_boot_schema: @post_boot_schema,
           endpoint: "/boot-source"}
  @enforce_keys [:kernel_image_path]
  defstruct [
    :boot_args,
    :initrd_path,
    :kernel_image_path,
    # internal
    applied?: false
  ]

  @type t :: %__MODULE__{
          boot_args: String.t() | nil,
          initrd_path: String.t() | nil,
          kernel_image_path: String.t(),
          applied?: boolean()
        }
end
