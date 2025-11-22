defmodule Firecracker.MachineConfig do
  @moduledoc """
  Configures the virtual machine's hardware specifications in Firecracker.

  This module defines core hardware characteristics of the VM including CPU count,
  memory size, and various performance-related features.

  ## Fields

    * `:mem_size_mib` - Required. Memory size in mebibytes (MiB)
    * `:vcpu_count` - Required. Number of virtual CPUs to allocate
    * `:smt` - Optional. Whether to enable Simultaneous Multithreading
    * `:track_dirty_pages` - Optional. Enable dirty page tracking for memory operations
    * `:huge_pages` - Optional. Use huge pages for memory allocation ("None", "2M")

  ## Post-boot Behavior

  All configuration fields can be modified after boot.

  ## Notes

    * Memory size is specified in mebibytes (MiB), not megabytes
    * vCPU count should match your workload requirements
    * Disabling SMT can improve security at the cost of performance
    * Dirty page tracking is useful for live migration scenarios
    * Huge pages can improve memory performance for large VMs
  """

  @pre_boot_schema NimbleOptions.new!(
                     mem_size_mib: [type: :pos_integer, required: true],
                     vcpu_count: [type: :pos_integer, required: true],
                     smt: [type: :boolean, required: false],
                     track_dirty_pages: [type: :boolean, required: false],
                     huge_pages: [type: :string, required: false],
                     cpu_template: [type: :string, required: false]
                   )

  @post_boot_schema NimbleOptions.new!(
                      smt: [type: :boolean, required: false],
                      mem_size_mib: [type: :pos_integer, required: false],
                      track_dirty_pages: [type: :boolean, required: false],
                      vcpu_count: [type: :pos_integer, required: false],
                      huge_pages: [type: :string, required: false],
                      cpu_template: [type: :string, required: false]
                    )

  @derive {Firecracker.Model,
           pre_boot_schema: @pre_boot_schema,
           post_boot_schema: @post_boot_schema,
           endpoint: "/machine-config"}
  @enforce_keys [:mem_size_mib, :vcpu_count]
  defstruct [
    :smt,
    :mem_size_mib,
    :track_dirty_pages,
    :vcpu_count,
    :huge_pages,
    :cpu_template,
    # internal
    applied?: false
  ]

  @type t :: %__MODULE__{
          smt: boolean() | nil,
          mem_size_mib: pos_integer(),
          track_dirty_pages: boolean() | nil,
          vcpu_count: pos_integer(),
          huge_pages: String.t() | nil,
          cpu_template: String.t() | nil,
          applied?: boolean()
        }
end
