defmodule Firecracker.BalloonHinting do
  @moduledoc """
  Manages free page hinting for Firecracker's balloon device.

  Free page hinting allows the guest to communicate which memory pages are
  free to the hypervisor, enabling more efficient memory management and
  potentially allowing the host to reclaim unused guest memory.

  ## Overview

  Balloon hinting works by:
  1. Starting a hinting run with `start_hinting/1`
  2. The guest reports free pages to the hypervisor
  3. Checking status with `hinting_status/1`
  4. Stopping the run with `stop_hinting/1`

  ## Example

      # Start free page hinting
      vm = Firecracker.start_hinting(vm)

      # Check the status
      status = Firecracker.hinting_status(vm)

      # Stop hinting when done
      vm = Firecracker.stop_hinting(vm)

  ## Notes

    * Requires a balloon device to be configured
    * The VM must be in a running state
    * Hinting is an asynchronous process - use status to monitor progress
  """

  defstruct [
    :hinting_count,
    :state
  ]

  @type hinting_state :: :not_started | :in_progress | :complete

  @type t :: %__MODULE__{
          hinting_count: non_neg_integer() | nil,
          state: hinting_state() | nil
        }

  @doc """
  Parses balloon hinting status from the API response.
  """
  @spec from_response(map()) :: t()
  def from_response(response) when is_map(response) do
    %__MODULE__{
      hinting_count: response["hinting_count"],
      state: parse_state(response["state"])
    }
  end

  defp parse_state("NotStarted"), do: :not_started
  defp parse_state("InProgress"), do: :in_progress
  defp parse_state("Complete"), do: :complete
  defp parse_state(nil), do: nil
  defp parse_state(other), do: other
end
