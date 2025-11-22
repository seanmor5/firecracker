defmodule Firecracker.RateLimiter do
  @moduledoc """
  A data-only representation of an I/O rate limiter in Firecracker.

  Firecracker implements a token bucket-based rate limiter for controlling both
  I/O bandwidth and operations frequency. Rate limiting can help prevent resource
  contention and ensure consistent performance when running multiple Firecracker
  instances.

  The rate limiter has two main components:

    * `:bandwidth` - Controls data transfer rates (bytes per second)
    * `:ops` - Controls operations frequency (operations per second)

  Both components use a token bucket algorithm where tokens are consumed for each
  operation and are replenished at a configured rate. Each bucket can be configured
  with:

    * `:size` - Maximum number of tokens the bucket can hold
    * `:refill_time` - Time in milliseconds between token refills
    * `:one_time_burst` - Additional tokens allowed for initial burst
  """
  alias Firecracker.RateLimiter.TokenBucket

  @derive Jason.Encoder
  defstruct [
    :bandwidth,
    :ops
  ]

  @type t :: %__MODULE__{
          bandwidth: TokenBucket.t() | nil,
          ops: TokenBucket.t() | nil
        }

  @doc """
  Creates a new I/O rate limiter.

  ## Options

    * `:bandwidth` - Configuration for bandwidth rate limiting (bytes/second)
      * `:size` - Maximum number of tokens (bytes) in the bucket
      * `:refill_time` - Time in milliseconds between token refills
      * `:one_time_burst` - Additional tokens allowed for the initial burst

    * `:ops` - Configuration for operations rate limiting (operations/second)
      * `:size` - Maximum number of operations tokens in the bucket
      * `:refill_time` - Time in milliseconds between token refills
      * `:one_time_burst` - Additional tokens allowed for the initial burst
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    opts = Keyword.validate!(opts, [:bandwidth, :ops])

    bandwidth = opts[:bandwidth]
    bandwidth = if bandwidth, do: bucket(bandwidth), else: nil
    ops = opts[:ops]
    ops = if ops, do: bucket(ops), else: nil

    struct(__MODULE__,
      bandwidth: bandwidth,
      ops: ops
    )
  end

  @doc """
  Configures the given rate limiter to rate limit bandwidth
  with the given configuration.

  ## Options

    * `:size` - Maximum number of tokens (bytes) in the bucket

    * `:refill_time` - Time in milliseconds between token refills

    * `:one_time_burst` - Additional tokens allowed for the initial burst
  """
  @spec bandwidth(t(), keyword()) :: t()
  def bandwidth(%__MODULE__{} = rate_limiter, opts \\ []) do
    opts = Keyword.validate!(opts, [:one_time_burst, :refill_time, :size])
    %{rate_limiter | bandwidth: bucket(opts)}
  end

  @doc """
  Configures the given rate limiter to rate limit ops
  with the given configuration.

  ## Options

    * `:size` - Maximum number of operations tokens in the bucket

    * `:refill_time` - Time in milliseconds between token refills

    * `:one_time_burst` - Additional tokens allowed for the initial burst
  """
  @spec ops(t(), keyword()) :: t()
  def ops(%__MODULE__{} = rate_limiter, opts \\ []) do
    opts = Keyword.validate!(opts, [:one_time_burst, :refill_time, :size])
    %{rate_limiter | ops: bucket(opts)}
  end

  defp bucket(opts) do
    struct(TokenBucket, opts)
  end

  @doc false
  def model(%__MODULE__{bandwidth: bw, ops: ops}) do
    %{
      "bandwidth" => to_api_config(bw),
      "ops" => to_api_config(ops)
    }
  end

  defp to_api_config(nil), do: nil

  defp to_api_config(struct) do
    struct
    |> Map.from_struct()
    |> Map.new(fn {k, v} -> {Atom.to_string(k), v} end)
  end
end
