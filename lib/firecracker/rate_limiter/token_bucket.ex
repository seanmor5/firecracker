defmodule Firecracker.RateLimiter.TokenBucket do
  @moduledoc false
  @derive Jason.Encoder
  defstruct [
    :one_time_burst,
    :refill_time,
    :size
  ]

  @type t :: %__MODULE__{
          one_time_burst: non_neg_integer() | nil,
          refill_time: non_neg_integer() | nil,
          size: non_neg_integer() | nil
        }
end
