defmodule Firecracker.Snapshot.MemoryBackend do
  @moduledoc false
  @derive Jason.Encoder
  defstruct [
    :backend_type,
    :backend_path
  ]

  @type t :: %__MODULE__{
          backend_type: String.t() | nil,
          backend_path: String.t() | nil
        }
end
