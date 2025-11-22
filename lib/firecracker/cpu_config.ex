defmodule Firecracker.CpuConfig do
  @moduledoc """
  Represents the CPU configuration settings for a Firecracker virtual machine.

  This module allows fine-grained control over virtual CPU characteristics including
  CPUID features, MSR (Model-Specific Register) settings, and KVM capabilities.

  ## Fields

    * `:cpuid_modifiers` - Optional. Modifiers for CPUID (CPU identification) instructions
    * `:msr_modifiers` - Optional. Modifiers for MSR (Model-Specific Register) behavior
    * `:reg_modifiers` - Optional. Modifiers for CPU register behavior
    * `:vcpu_features` - Optional. Feature flags for virtual CPU configuration
    * `:kvm_capabilities` - Optional. KVM (Kernel-based Virtual Machine) specific capabilities

  ## Post-boot Configuration

  No fields can be modified after VM starts
  """

  # TODO: Much better CPU Configuration validation

  @pre_boot_schema NimbleOptions.new!(
                     cpuid_modifiers: [type: {:list, :any}, required: false],
                     msr_modifiers: [type: {:list, :any}, required: false],
                     reg_modifiers: [type: {:list, :any}, required: false],
                     vcpu_features: [type: {:list, :any}, required: false],
                     kvm_capabilities: [type: {:list, :any}, required: false]
                   )

  @post_boot_schema NimbleOptions.new!([])

  @derive {Firecracker.Model,
           pre_boot_schema: @pre_boot_schema,
           post_boot_schema: @post_boot_schema,
           endpoint: "/cpu-config"}
  defstruct [
    :cpuid_modifiers,
    :msr_modifiers,
    :reg_modifiers,
    :vcpu_features,
    :kvm_capabilities,
    # internal
    applied?: false
  ]

  @type t :: %__MODULE__{
          cpuid_modifiers: list() | nil,
          msr_modifiers: list() | nil,
          reg_modifiers: list() | nil,
          vcpu_features: list() | nil,
          kvm_capabilities: list() | nil,
          applied?: boolean()
        }
end
