defmodule Firecracker.RateLimiterTest do
  use ExUnit.Case, async: true

  alias Firecracker.RateLimiter
  alias Firecracker.RateLimiter.TokenBucket

  describe "new/1" do
    test "creates a rate limiter with default values" do
      limiter = RateLimiter.new()

      assert %RateLimiter{bandwidth: nil, ops: nil} = limiter
    end

    test "creates a rate limiter with bandwidth configuration" do
      limiter =
        RateLimiter.new(
          bandwidth: [size: 10_000_000, refill_time: 100, one_time_burst: 5_000_000]
        )

      assert %RateLimiter{
               bandwidth: %TokenBucket{
                 size: 10_000_000,
                 refill_time: 100,
                 one_time_burst: 5_000_000
               },
               ops: nil
             } = limiter
    end

    test "creates a rate limiter with ops configuration" do
      limiter = RateLimiter.new(ops: [size: 1000, refill_time: 50, one_time_burst: 500])

      assert %RateLimiter{
               bandwidth: nil,
               ops: %TokenBucket{
                 size: 1000,
                 refill_time: 50,
                 one_time_burst: 500
               }
             } = limiter
    end

    test "creates a rate limiter with both bandwidth and ops configuration" do
      limiter =
        RateLimiter.new(
          bandwidth: [size: 10_000_000, refill_time: 100, one_time_burst: 5_000_000],
          ops: [size: 1000, refill_time: 50, one_time_burst: 500]
        )

      assert %RateLimiter{
               bandwidth: %TokenBucket{
                 size: 10_000_000,
                 refill_time: 100,
                 one_time_burst: 5_000_000
               },
               ops: %TokenBucket{
                 size: 1000,
                 refill_time: 50,
                 one_time_burst: 500
               }
             } = limiter
    end

    test "validates options and raises on invalid keys" do
      assert_raise ArgumentError, fn ->
        RateLimiter.new(invalid_key: [])
      end
    end
  end

  describe "bandwidth/2" do
    test "configures bandwidth on an existing rate limiter" do
      limiter =
        RateLimiter.new()
        |> RateLimiter.bandwidth(size: 10_000_000, refill_time: 100, one_time_burst: 5_000_000)

      assert %RateLimiter{
               bandwidth: %TokenBucket{
                 size: 10_000_000,
                 refill_time: 100,
                 one_time_burst: 5_000_000
               },
               ops: nil
             } = limiter
    end

    test "overrides existing bandwidth configuration" do
      limiter =
        RateLimiter.new(bandwidth: [size: 1, refill_time: 1, one_time_burst: 1])
        |> RateLimiter.bandwidth(size: 100, refill_time: 200, one_time_burst: 50)

      assert limiter.bandwidth.size == 100
      assert limiter.bandwidth.refill_time == 200
      assert limiter.bandwidth.one_time_burst == 50
    end

    test "preserves ops configuration when bandwidth is modified" do
      limiter =
        RateLimiter.new(ops: [size: 999, refill_time: 888, one_time_burst: 777])
        |> RateLimiter.bandwidth(size: 100)

      assert limiter.ops.size == 999
      assert limiter.ops.refill_time == 888
      assert limiter.ops.one_time_burst == 777
    end

    test "validates options and raises on invalid keys" do
      limiter = RateLimiter.new()

      assert_raise ArgumentError, fn ->
        RateLimiter.bandwidth(limiter, invalid_key: 100)
      end
    end
  end

  describe "ops/2" do
    test "configures ops on an existing rate limiter" do
      limiter =
        RateLimiter.new()
        |> RateLimiter.ops(size: 1000, refill_time: 50, one_time_burst: 500)

      assert %RateLimiter{
               bandwidth: nil,
               ops: %TokenBucket{
                 size: 1000,
                 refill_time: 50,
                 one_time_burst: 500
               }
             } = limiter
    end

    test "overrides existing ops configuration" do
      limiter =
        RateLimiter.new(ops: [size: 1, refill_time: 1, one_time_burst: 1])
        |> RateLimiter.ops(size: 100, refill_time: 200, one_time_burst: 50)

      assert limiter.ops.size == 100
      assert limiter.ops.refill_time == 200
      assert limiter.ops.one_time_burst == 50
    end

    test "preserves bandwidth configuration when ops is modified" do
      limiter =
        RateLimiter.new(bandwidth: [size: 999, refill_time: 888, one_time_burst: 777])
        |> RateLimiter.ops(size: 100)

      assert limiter.bandwidth.size == 999
      assert limiter.bandwidth.refill_time == 888
      assert limiter.bandwidth.one_time_burst == 777
    end

    test "validates options and raises on invalid keys" do
      limiter = RateLimiter.new()

      assert_raise ArgumentError, fn ->
        RateLimiter.ops(limiter, invalid_key: 100)
      end
    end
  end
end
