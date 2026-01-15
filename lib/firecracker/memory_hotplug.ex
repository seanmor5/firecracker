defmodule Firecracker.MemoryHotplug do
  @moduledoc """
  Configures memory hotplug for a Firecracker virtual machine.

  Memory hotplug allows dynamically adding memory to a running VM without
  requiring a reboot. This is useful for scaling memory resources based on
  workload demands.

  ## Fields

    * `:hotplug_size_mib` - The amount of hotpluggable memory in MiB. This memory
      can be dynamically added to the VM after boot.
    * `:applied?` - Internal flag indicating whether this configuration has been applied

  ## Usage

  Memory hotplug must be configured before the VM boots. After boot, you can
  increase the memory size using `Firecracker.resize_memory/2`.

  ## Example

      vm =
        Firecracker.new()
        |> Firecracker.configure(:memory_hotplug, hotplug_size_mib: 1024)
        |> Firecracker.start()
        |> Firecracker.boot()

      # Later, resize memory
      vm = Firecracker.resize_memory(vm, 512)

  ## Notes

    * Memory hotplug requires guest kernel support
    * The hotplug_size_mib sets the maximum amount of memory that can be hot-added
    * Memory can only be increased, not decreased, after boot
  """

  @pre_boot_schema NimbleOptions.new!(
                     hotplug_size_mib: [type: :non_neg_integer, required: false]
                   )

  @post_boot_schema NimbleOptions.new!(
                      hotplug_size_mib: [type: :non_neg_integer, required: false]
                    )

  @derive {Firecracker.Model,
           pre_boot_schema: @pre_boot_schema,
           post_boot_schema: @post_boot_schema,
           endpoint: "/hotplug/memory"}
  defstruct [
    :hotplug_size_mib,
    # internal
    applied?: false
  ]

  @type t :: %__MODULE__{
          hotplug_size_mib: non_neg_integer() | nil,
          applied?: boolean()
        }
end
