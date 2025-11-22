defmodule Firecracker.Balloon do
  @moduledoc """
  Represents the balloon device configuration for a Firecracker virtual machine.

  The balloon device is used for memory management in Firecracker VMs by allowing
  dynamic memory allocation/deallocation. This module provides configuration for:

    * Memory inflation/deflation within the guest VM
    * Handling out-of-memory conditions
    * Statistics polling intervals

  ## Fields

    * `:amount_mib` - Required. The amount of memory in mebibytes to assign to the balloon device
    * `:deflate_on_oom` - Required. Whether to deflate the balloon when the host experiences
      out-of-memory conditions  
    * `:stats_polling_interval_s` - Optional. The interval in seconds for polling balloon statistics

  ## Post-boot Behavior

  Both `:amount_mib` and `:stats_polling_interval_s` can be modified after VM starts.
  """

  @pre_boot_schema NimbleOptions.new!(
                     amount_mib: [
                       type: :non_neg_integer,
                       required: true
                     ],
                     deflate_on_oom: [
                       type: :boolean,
                       required: true
                     ],
                     stats_polling_interval_s: [
                       type: :non_neg_integer,
                       required: false
                     ]
                   )

  @post_boot_schema NimbleOptions.new!(
                      amount_mib: [type: :non_neg_integer, required: false],
                      stats_polling_interval_s: [type: :non_neg_integer, required: false]
                    )

  @derive {Firecracker.Model,
           pre_boot_schema: @pre_boot_schema,
           post_boot_schema: @post_boot_schema,
           endpoint: "/balloon"}
  @enforce_keys [:amount_mib, :deflate_on_oom]
  defstruct [
    :amount_mib,
    :deflate_on_oom,
    :stats_polling_interval_s,
    # internal
    applied?: false
  ]

  @type t :: %__MODULE__{
          amount_mib: pos_integer(),
          deflate_on_oom: boolean(),
          stats_polling_interval_s: pos_integer() | nil,
          applied?: boolean()
        }
end
