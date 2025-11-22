defmodule Firecracker.Snapshot do
  @doc """
  A data-only representation of a Firecracker snapshot.

  This module creates and manages snapshot configurations for Firecracker VMs,
  allowing you to save and restore the state of virtual machines. Snapshots
  include both the VM state (CPU registers, VM configuration) and optionally 
  the guest memory content.

  ## Snapshot Types

  Firecracker supports two types of snapshots:
    
    * `:full` - Contains both VM state and guest memory
    * `:diff` - Contains only incremental changes from a previous snapshot

  ## Memory Management

  Firecracker snapshots can manage guest memory content through:
    
    * Memory files (`.mem` files) that store the raw memory contents
    * Memory backends that provide alternative memory storage mechanisms

  The snapshot configuration can be created with either a direct path to 
  a memory file or by associating it with a memory backend later.

  ## Network Overrides

  When loading a snapshot, you can override the network interface configurations
  to change which host devices back the virtual machine's network interfaces.
  This is useful when restoring VM snapshots in different network environments 
  or when the original host device is no longer available.

  Network overrides are configured by interface ID and allow you to map a 
  VM's virtual network interface to a different host device without modifying
  the underlying snapshot. See `network_override/3` for details.

  ## Example Usage

      # Create a basic snapshot configuration
      snapshot = Firecracker.Snapshot.new(
        path: "/path/to/snapshot.json",
        type: :full,
        mem_file_path: "/path/to/memory.mem"
      )

      # Or create with a memory backend
      snapshot = Firecracker.Snapshot.new(path: "/path/to/snapshot.json", type: :diff)
      |> Firecracker.Snapshot.memory_backend(custom_backend)
  """
  alias Firecracker.Snapshot.MemoryBackend

  defstruct [
    :mem_file_path,
    :snapshot_path,
    :snapshot_type,
    memory_backend: nil,
    resume_vm: true,
    track_dirty_pages: true,
    network_overrides: %{}
  ]

  @type snapshot_type :: :full | :diff
  @type t :: %__MODULE__{
          mem_file_path: String.t() | nil,
          snapshot_path: String.t() | nil,
          snapshot_type: snapshot_type() | nil,
          memory_backend: MemoryBackend.t() | nil,
          resume_vm: boolean(),
          track_dirty_pages: boolean(),
          network_overrides: %{String.t() => String.t()}
        }

  @doc """
  Creates a `%Firecracker.Snapshot{}` struct with the
  given configuration options.

  You must pass a `:path` which is a valid path to a valid Firecracker
  snapshot, as well as a `:type` which is the type of Firecracker snapshot.

  You may optionall pass a `:mem_file_path` which is a pass to a file containing
  the guest memory. If you do not configure `:mem_file_path` here, you must configure
  a memory backend using `Firecracker.Snapshot.memory_backend/2`.

  ## Options

    * `:path` - snapshot path. Required

    * `:type` - snapshot type. Required

    * `:resume_vm` - whether or not to resume the VM after loading the snapshot.
      Defaults to `true`

    * `:track_dirty_pages` - whether or not to enable KVM dirty page tracking.
      Defaults to `true`

    * `:mem_file_path` - path to a file which contains guest memory. You must configure
      this or a memory backend before loading the snapshot.
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    opts = Keyword.validate!(opts, [:path, :type, :resume_vm, :mem_file_path])

    path = opts[:path] || raise ArgumentError, ":path is required"
    type = opts[:type] || raise ArgumentError, ":type is required"
    mem_file_path = opts[:mem_file_path]
    resume_vm = Keyword.get(opts, :resume_vm, true)

    %__MODULE__{
      snapshot_path: path,
      snapshot_type: type,
      mem_file_path: mem_file_path,
      resume_vm: resume_vm
    }
  end

  @doc """
  Sets the given snapshot options.

  This can be used to modify snapshot configuration options after
  creating a snapshot via `Firecracker.snapshot/2`.

  ## Options

    * `:path` - snapshot path

    * `:type` - snapshot type

    * `:track_dirty_pages` - whether or not to enable KVM dirty page tracking.
      Defaults to `true`

    * `:mem_file_path` - path to a file which contains guest memory. You must configure
      this or a memory backend before loading the snapshot.
  """
  @spec set_options(t(), keyword()) :: t()
  def set_options(%Firecracker.Snapshot{} = snapshot, opts \\ []) do
    opts = Keyword.validate!(opts, [:path, :type, :resume_vm, :mem_file_path])

    Enum.reduce(opts, snapshot, fn
      {_, v}, snapshot when is_nil(v) ->
        snapshot

      {:path, v}, snapshot ->
        %{snapshot | snapshot_path: v}

      {:type, v}, snapshot ->
        %{snapshot | snapshot_type: v}

      {k, v}, snapshot ->
        %{snapshot | k => v}
    end)
  end

  @doc """
  Creates a snapshot memory backend.

  Memory backends can be used in place of the memory file path
  when loading a snapshot.

  Setting the memory backend overrides the existing `:mem_file_path`
  if one is set.

  ## Options

    * `:backend_type` - the type of memory backend to use. One of
      "File" or "Uffd"

    * `:backend_path` - if the backend type is `File`, this must be
      the path to the file that contains the guest memory. If if is
      Uffd, it must be the path to the UDS where a process is listening
      for a UFFD initialization control payload.
  """
  @spec memory_backend(t(), keyword()) :: t()
  def memory_backend(%Firecracker.Snapshot{} = snapshot, opts \\ []) do
    opts = Keyword.validate!(opts, [:backend_path, :backend_type])
    backend_type = opts[:backend_type] || raise "backend_type is required"
    backend_path = opts[:backend_path] || raise "backend_path is required"
    backend = %MemoryBackend{backend_type: backend_type, backend_path: backend_path}
    %{snapshot | mem_file_path: nil, memory_backend: backend}
  end

  @doc """
  Creates a network override for the given interface
  with the given host device name.

  The `id` must be an existing `iface_id` on the virutal machine and the
  given `host_dev_name` will be the new backing host device.
  """
  @spec network_override(t(), String.t(), String.t()) :: t()
  def network_override(%Firecracker.Snapshot{} = snapshot, id, host_dev_name) do
    %{snapshot | network_overrides: Map.put(snapshot.network_overrides, id, host_dev_name)}
  end
end
