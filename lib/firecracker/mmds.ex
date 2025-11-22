defmodule Firecracker.Mmds do
  @moduledoc false
  defstruct data: %{},
            applied?: false

  @type t :: %__MODULE__{
          data: map(),
          applied?: boolean()
        }

  defimpl Firecracker.Model, for: __MODULE__ do
    def validate_change!(_, _, _), do: :ok

    def put(%{data: data}), do: data

    def patch(%{data: data}), do: data

    def endpoint(_), do: "/mmds"
  end
end
