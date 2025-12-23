defmodule Firecracker do
  @moduledoc """
  `Firecracker` is a low-level interface for interacting with [Firecracker VMs](https://github.com/firecracker-microvm/firecracker).

  This library is intentionally low-level and makes few deviations from the API
  surface exposed by Firecracker. If you are looking for a simpler, higher-level
  VM orchestrator, [stay tuned](#).

  > #### System Requirements {: .info}
  > In order to run Firecracker, you must be running on a machine that supports virtualizaiton and KVM. You
  > can use the [checkenv](https://github.com/firecracker-microvm/firecracker/blob/2b05435cd4f1d8cb14a002c6d884a42a9a5290b6/tools/devtool)
  > devtool provided by the Firecracker developers to determine if your machine supports
  > running the Firecracker binary.

  ## Overview

  `Firecracker` lets you create VMs programmatically. You start by creating a new VM
  struct with `Firecracker.new/1`:

      vm = Firecracker.new()

  This creates a `%Firecracker{}` struct which is meant to be an Elixir representation of
  a Firecracker VM.

  You can configure the VM by manipulating the data structure with the various helper
  functions. Options are configurable via `Firecracker.set_option/3`:

      vm =
        Firecracker.new()
        |> Firecracker.set_option(:api_sock, "/tmp/firecracker.sock")

  Options represent Firecracker "process" options and are _mostly_ one-to-one to the binary
  CLI arguments. Detailed VM configuration options can be configured via `Firecracker.configure/3`
  or `Firecracker.add/4`.

  `Firecracker.configure/3` lets you configure VM-specific settings. For example, you can configure
  the machine configuration:

      vm =
        Firecracker.new()
        |> Firecracker.configure(:machine_config, vcpu_count: 3)

  `Firecracker.add/4` lets you add VM devices such as drives, network interfaces or persistent memory devices:

      vm =
        Firecracker.new()
        |> Firecracker.add(:drive, "root", is_root_device: true)

  VM configurations map directly to the VM configurations present in the Firecracker
  API. See the respective module documentation for per-resource options:

    * `Firecracker.Balloon`
    * `Firecracker.BootSource`
    * `Firecracker.CpuConfig`
    * `Firecracker.Drive`
    * `Firecracker.Entropy`
    * `Firecracker.Logger`
    * `Firecracker.MachineConfig`
    * `Firecracker.MmdsConfig`
    * `Firecracker.NetworkInterface`
    * `Firecracker.Pmem`
    * `Firecracker.Serial`
    * `Firecracker.Vsock`

  ## Prerequisites

  Before you can use this library, you should ensure you have the Firecracker binary
  and jailer binary downloaded on your system. You can download all of the Firecracker
  project binaries with the mix task:

      mix firecracker.install

  This will download the latest Firecracker binaries for your system architecture to
  `$HOME/.firecracker/bin`.

  ## Starting Firecracker VMs

  Calling `Firecracker.new/1` does not actually start a Firecracker process. The struct
  representation is data-only up until the point you call `Firecracker.start/1`:

      vm =
        Firecracker.new()
        |> Firecracker.set_option(:api_sock, "/tmp/firecracker.sock")
        |> Firecracker.start()

  After starting, you'll notice the struct state changes from `:initial` to `:started` and
  has an attached PID. This PID represents the externally running Firecracker process. It's
  important to note that this library does not do any automatic cleanup. Failure to call
  `Firecracker.stop/1` on created VMs will result in zombie processes.

  `Firecracker.start/1` simply starts the Firecracker process. To boot the actual VM you
  must call `Firecracker.boot/1`. In order to boot, you need to configure the VM with a kernel
  image and rootfs:

      vm =
        Firecracker.new()
        |> Firecracker.set_option(:api_sock, "/tmp/firecracker.sock")
        |> Firecracker.configure(:boot_source, kernel_image_path: kernel)
        |> Firecracker.add(:drive, "rootfs",
          path_on_host: rootfs,
          is_root_device: true,
          is_read_only: false
        )
        |> Firecracker.start()
        |> Firecracker.boot()

  After booting a VM, you can pause the VM:
      
      vm =
        Firecracker.new()
        |> Firecracker.set_option(:api_sock, "/tmp/firecracker.sock")
        |> Firecracker.configure(:boot_source, kernel_image_path: kernel)
        |> Firecracker.add(:drive, "rootfs",
          path_on_host: rootfs,
          is_root_device: true,
          is_read_only: false
        )
        |> Firecracker.start()
        |> Firecracker.boot()

      paused = Firecracker.pause(vm)

  Or shutdown the VM:

      vm =
        Firecracker.new()
        |> Firecracker.set_option(:api_sock, "/tmp/firecracker.sock")
        |> Firecracker.configure(:boot_source, kernel_image_path: kernel)
        |> Firecracker.add(:drive, "rootfs",
          path_on_host: rootfs,
          is_root_device: true,
          is_read_only: false
        )
        |> Firecracker.start()
        |> Firecracker.boot()

      shutdown = Firecracker.shutdown(vm)

  Note that shutting down the VM **does not kill the Firecracker process**. To stop the running
  process, you **must** use `Firecracker.stop/1`:

      vm =
        Firecracker.new()
        |> Firecracker.set_option(:api_sock, "/tmp/firecracker.sock")
        |> Firecracker.configure(:boot_source, kernel_image_path: kernel)
        |> Firecracker.add(:drive, "rootfs",
          path_on_host: rootfs,
          is_root_device: true,
          is_read_only: false
        )
        |> Firecracker.start()
        |> Firecracker.boot()

      Firecracker.stop(vm)

  `Firecracker.stop/1` will ensure all of the resources associated with the VM are cleaned up
  properly. Internally, `Firecracker.stop/1` sends `SIGTERM` to the running process, waits for
  the process to exit, and then cleans up all created sockets. The returned VM will be in an
  `:exited` state and cannot be restarted.

  ## Applying configuration changes

  At any point after a VM has been started, you can change a VM's configuration
  options and re-apply them to the VM using `Firecracker.apply/1`. Configuration changes via
  functions like `Firecracker.configure/3` and `Firecracker.add/4` are data only until they
  have been properly applied:

      vm =
        Firecracker.new()
        |> Firecracker.set_option(:api_sock, "/tmp/firecracker.sock")
        |> Firecracker.configure(:boot_source, kernel_image_path: kernel)
        |> Firecracker.start()

      # change the kernel and add a rootfs after start
      vm =
        Firecracker.new()
        |> Firecracker.configure(:boot_source, kernel_image_path: new_kernel)
        |> Firecracker.add(:drive, "rootfs",
          path_on_host: rootfs,
          is_root_device: true,
          is_read_only: false
        )

      # apply the changes
      vm = Firecracker.apply(vm)

  You can inspect what configuration changes will be applied by using `Firecracker.dry_run/1`

      IO.inspect Firecracker.dry_run(vm)

      # will show a configuration object
      %{config: "vsock" => %{"guest_cid" => 3, "uds_path" => "/tmp/vsock.sock"}}

  The Firecracker data structure keeps track of which configurations have changed since the last
  persisted update, and will only make the changes necessary.

  Note that some changes are valid _only_ pre-boot. If you attempt to make a change which is invalid
  after a VM is in a booted state, the update will fail.

  ## Jailer

  You can configure the VM to run within the Firecracker Jailer for enhanced security and resource
  isolation. The jailer provides sandboxing by switching to a non-root user, constraining the microVM
  to a chroot environment, and optionally setting up cgroups and resource limits.

  To use the jailer, you must configure it before starting the VM. The uid and gid options are required:

      vm =
        Firecracker.new()
        |> Firecracker.jail(uid: 1000, gid: 1000)
        |> Firecracker.set_option(:api_sock, "/tmp/firecracker.sock")
        |> Firecracker.start()

  You can optionally specify additional jailer configuration:

      vm =
        Firecracker.new()
        |> Firecracker.jail(
          uid: 1000,
          gid: 1000,
          chroot_base_dir: "/srv/myjailer",
          netns: "/var/run/netns/custom-ns",
          parent_cgroup: "custom.slice"
        )

  ### Configuring cgroups

  Once a jailer is configured, you can set cgroup constraints:

      vm =
        Firecracker.new()
        |> Firecracker.jail(uid: 1000, gid: 1000)
        |> Firecracker.cgroup("memory.limit_in_bytes", "512M")
        |> Firecracker.cgroup("cpu.cfs_quota_us", "100000")

  ### Configuring resource limits

  You can also set resource limits for the jailed process:

      vm =
        Firecracker.new()
        |> Firecracker.jail(uid: 1000, gid: 1000)
        |> Firecracker.resource_limit("fsize", 1024 * 1024 * 1024)
        |> Firecracker.resource_limit("no-file", 1024)

  ## Inspection

  At any point after starting a VM, you can inspect the configuration options and status
  of the VM using `Firecracker.describe/1` or `Firecracker.describe/2`. `Firecracker.describe/1`
  will provide basic information about the state of your VM:

      Firecracker.describe(vm)

  This will show:

      %{
        "id" => "anonymous-instance",
        "state" => "Running", 
        "app_name" => "Firecracker",
        "vmm_version" => "1.0.0"
      }

  `Firecracker.describe/2` can be used to inspect specific configurations and metadata:

      # Inspect machine configuration
      machine_config = Firecracker.describe(vm, :machine_config)
      # Returns CPU count, memory size, etc.

      # Check balloon device configuration  
      balloon_config = Firecracker.describe(vm, :balloon)
      # Returns target memory size if balloon is configured

      # Get balloon statistics (memory reclamation stats)
      balloon_stats = Firecracker.describe(vm, :balloon_statistics)
      # Returns actual memory usage, target memory, etc.

      # View metadata store contents
      mmds_data = Firecracker.describe(vm, :mmds)
      # Returns the current metadata key-value pairs

      # Get complete VM configuration
      vm_config = Firecracker.describe(vm, :vm_config)
      # Returns full configuration including drives, network interfaces, etc.

  ## Snapshots

  Firecracker supports creating snapshots of running VMs, which capture the complete state of
  the microVM including CPU registers, device states, and memory contents. Snapshots can be
  used for fast VM startup from saved states, creating VM templates, or implementing rollback
  functionality.

  To create a snapshot, the VM must first be paused. Only paused VMs can be snapshotted to ensure
  consistent state:

      # Start and boot a VM
      vm =
        Firecracker.new()
        |> Firecracker.set_option(:api_sock, "/tmp/firecracker.sock")
        |> Firecracker.configure(:boot_source, kernel_image_path: kernel)
        |> Firecracker.add(:drive, "rootfs",
          path_on_host: rootfs,
          is_root_device: true,
          is_read_only: false
        )
        |> Firecracker.start()
        |> Firecracker.boot()

      # Pause the VM to prepare for snapshot
      paused_vm = Firecracker.pause(vm)

      # Create a full snapshot
      snapshot = Firecracker.snapshot(paused_vm,
        mem_file_path: "/path/to/memory.mem",
        snapshot_path: "/path/to/vm-state.json",
        type: :full
      )

  Firecracker supports two types of snapshots:

    * `:full` snapshots capture the complete VM state and memory
    * `:diff` snapshots capture only the changes since the last snapshot

  To load a snapshot, you must create and start (but not boot!) a VM. Then, you can load
  the VM from a snapshot created with `Firecracker.snapshot/2`, or from a snapshot configured
  using the `Firecracker.Snapshot` module:

      new_vm =
        Firecracker.new()
        |> Firecracker.set_option(:api_sock, "/tmp/firecracker-new.sock")
        |> Firecracker.start()

      # Create a snapshot from file paths
      snapshot = Firecracker.Snapshot.new(
        path: "/path/to/vm-state.json",
        type: :full,
        mem_file_path: "/path/to/file.mem"
      )

      resumed_vm = Firecracker.load(new_vm, snapshot)


  When loading snapshots, you can override network interface configurations to adapt to different
  host environments:

      snapshot =
        Firecracker.Snapshot.new(
          path: "/path/to/vm-state.json",
          type: :full,
          mem_file_path: "/path/to/memory.mem"
        )
        |> Firecracker.Snapshot.network_override("eth0", host_dev_name: "tap1")

      restored_vm = Firecracker.load(new_vm, snapshot)

  This is particularly useful when:

    * Restoring VMs on different hosts
    * The original TAP device names are no longer available
    * You need to reconfigure networking after restore

  ## Metadata

  Firecracker provides a metadata service (MMDS) that allows you to inject custom data into
  your VMs. This metadata can be accessed from within the VM and is particularly useful for
  configuration management, initialization scripts, and passing runtime parameters.

  You can configure metadata for your VM using the `Firecracker.metadata/2` and `Firecracker.metadata/3`
  functions. There are two ways to set metadata. Either by setting the complete metadata up front:

      vm =
        Firecracker.new()
        |> Firecracker.metadata(%{
          "user_data" => "#!/bin/bash\necho 'Hello from metadata!'",
          "hostname" => "firecracker-vm",
          "environment" => "production",
          "config" => %{
            "database_url" => "postgres://localhost:5432/mydb",
            "api_key" => "abc123"
          }
        })

  Or by setting/updating individual keys:

      vm =
        Firecracker.new()
        |> Firecracker.metadata("user_data", "#!/bin/bash\necho 'Hello!'")
        |> Firecracker.metadata("instance_id", "i-1234567890abcdef")

  Like other configuration changes, metadata modifications are data-only until applied. You need to
  explicitly apply them:

      # Before starting the VM
      vm =
        Firecracker.new()
        |> Firecracker.metadata("hostname", "web-server-1")
        |> Firecracker.start()  # Metadata is applied when starting

      # After the VM is running
      vm =
        vm
        |> Firecracker.metadata("status", "active")
        |> Firecracker.apply()  # Apply metadata changes to running VM

  You can inspect the metadata of a VM using `Firecracker.describe/2` with `:mmds` key:

      Firecracker.describe(vm, :mmds)

  ## I/O Rate Limiters

  Firecracker provides fine-grained control over I/O operations through rate limiters that use a
  token bucket algorithm. These limiters help manage resource contention and ensure predictable
  performance when running multiple VMs.

  Rate limiters control two aspects of I/O operations:

    * Bandwidth - controls data transfer rate (bytes per second)
    * Operations - controls frequency of I/O operations (operations per second)

  You can create rate limiters with specific configurations:

      # Basic rate limiter with default settings
      limiter = Firecracker.RateLimiter.new()

      # Rate limiter with bandwidth constraints
      limiter = Firecracker.RateLimiter.new(
        bandwidth: [
          size: 10_000_000,          # 10MB bucket size
          refill_time: 100,          # Refill every 100ms
          one_time_burst: 5_000_000  # 5MB initial burst
        ]
      )

      # Rate limiter with operations constraints  
      limiter = Firecracker.RateLimiter.new(
        ops: [
          size: 1000,                # 1000 operations max
          refill_time: 1000,         # Refill every second
          one_time_burst: 100        # 100 extra ops for burst
        ]
      )

      # Combined bandwidth and operations limits
      limiter = Firecracker.RateLimiter.new(
        bandwidth: [size: 5_000_000, refill_time: 50],
        ops: [size: 500, refill_time: 100]
      )

  And apply them to any configuration that supports rate limiters:

      Firecracker.configure(vm, :entropy, rate_limiter: limiter)
  """
  require Logger

  alias __MODULE__, as: Firecracker
  alias Firecracker.Client

  defstruct [
    # cli configuration
    api_sock: nil,
    id: nil,
    firecracker_path: nil,
    options: %{},
    no_api: false,
    config_file: nil,
    # jailer
    jailer: nil,
    # device/api configuration
    balloon: nil,
    boot_source: nil,
    cpu_config: nil,
    drives: %{},
    logger: nil,
    machine_config: nil,
    metrics: nil,
    mmds_config: nil,
    network_interfaces: %{},
    pmems: %{},
    vsock: nil,
    mmds: nil,
    entropy: nil,
    serial: nil,
    # tracing
    tracing: nil,
    # lifecycle
    state: :initial,
    req: nil,
    process: nil,
    errors: []
  ]

  @type vm_state :: :initial | :started | :running | :paused | :shutdown | :exited
  @type configurable ::
          :balloon
          | :boot_source
          | :cpu_config
          | :entropy
          | :logger
          | :machine_config
          | :metrics
          | :mmds_config
          | :serial
          | :vsock
  @type addable :: :drive | :network_interface | :pmem
  @type describable :: :balloon | :balloon_statistics | :machine_config | :mmds | :vm_config

  @type t :: %__MODULE__{
          api_sock: String.t() | nil,
          id: String.t() | nil,
          firecracker_path: String.t() | nil,
          options: map(),
          jailer: Firecracker.Jailer.t() | nil,
          balloon: Firecracker.Balloon.t() | nil,
          boot_source: Firecracker.BootSource.t() | nil,
          cpu_config: Firecracker.CpuConfig.t() | nil,
          drives: %{String.t() => Firecracker.Drive.t()},
          logger: Firecracker.Logger.t() | nil,
          machine_config: Firecracker.MachineConfig.t() | nil,
          metrics: Firecracker.Metrics.t() | nil,
          mmds_config: Firecracker.MmdsConfig.t() | nil,
          network_interfaces: %{String.t() => Firecracker.NetworkInterface.t()},
          pmems: %{String.t() => Firecracker.Pmem.t()},
          vsock: Firecracker.Vsock.t() | nil,
          mmds: Firecracker.Mmds.t() | nil,
          entropy: Firecracker.Entropy.t() | nil,
          serial: Firecracker.Serial.t() | nil,
          state: vm_state(),
          req: Req.Request.t() | nil,
          process: term() | nil
        }

  ## Configuration

  @doc """
  Creates a new data-only representation of a VM.

  Options passed here will set CLI options for use before running the
  Firecracker binary.

  ## Options

    * `:api_sock` - Path of the unix socket to use for the VM API. Defaults
      to `"/tmp/firecracker.\#{System.unique_integer([:positive])}}.sock"`.

    * `:boot_timer` - Whether or not to load boot timer device for logging elapsed
      time since InstanceStart command.

    * `:config_file` - Path to a file that contains the microVM configuration in JSON
      format. Note that setting this option will override any configurations you set.
      This is not recommended.
    
    * `:enable_pci` - Enables PCIe support.

    * `:http_api_max_payload_size` - Http API request payload max size, in bytes.
      Defaults to 51200.

    * `:id` - MicroVM unique identifier. Defaults to `"anonymous-instance-\#{System.unique_integer([:positive])}"`.
      IDs should unique across all running VM instances.

    * `:level` - Firecracker log level.

    * `:log_path` - Path to a fifo or file used for configuring the logger on startup.

    * `:metadata` - Path to a file that contains metadata in JSON format to add to the mmds.

    * `:metrics_path` - Path to a fifo or a file used for configuring the metrics
      on startup.

    * `:mmds_size_limit` - Mmds data store limit, in bytes.

    * `:module` - Set the logger module filter.

    * `:no_api` - Optional parameter which allows starting and using a microVM
      without an active API socket.

    * `:no_seccomp` - Optional parameter which allows starting and using a microVM
      without seccomp filtering. Not recommended.

    * `:parent_cpu_time_us` - Parent process CPU time (wall clock, microseconds).
      This parameter is optional.

    * `:seccomp_filter` - Optional parameter which allows specifying the path to a custom
      seccomp filter. For advanced users.

    * `:show_level` - Whether or not to output the level in the logs.

    * `:show_log_origin` - Whether or not to include the file path and line number of
      the log's origin.
    
    * `:start_time_cpu_us` - Process start CPU time (wall clock, microseconds).
      This parameter is optional.

    * `:start_time_us` - Process start time (wall clock, microseconds). This parameter
      is optional.
  """
  @doc type: :creation
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    opts =
      opts
      |> Keyword.update(:id, default_id(), & &1)
      |> Keyword.update(:api_sock, default_api_sock(), & &1)

    Firecracker.set_options(%Firecracker{}, opts)
  end

  @configurables [
    :balloon,
    :boot_source,
    :cpu_config,
    :entropy,
    :logger,
    :machine_config,
    :metrics,
    :mmds_config,
    :serial,
    :vsock
  ]

  @doc """
  Updates the VM configuration given by the given key.

  Valid configurables are:

      * `:balloon`
      * `:boot_source`
      * `:cpu_config`
      * `:entropy`
      * `:logger`
      * `:machine_config`
      * `:metrics`
      * `:mmds_config`
      * `:serial`
      * `:vsock`

  Configuration options for each API map directly to the Firecracker
  API spec. See the corresponding configuration module's documentation
  for more detailed information.

  Note this change is data-only. Changes are only applied after calling
  `Firecracker.start/1` or `Firecracker.apply/1`.
  """
  @doc type: :configuration
  @spec configure(t(), configurable(), keyword()) :: t()
  def configure(%Firecracker{state: state} = vm, configurable, config)
      when configurable in @configurables do
    module = Module.concat(Firecracker, Macro.camelize(Atom.to_string(configurable)))
    model = struct(module, %{})
    Firecracker.Model.validate_change!(model, config, state)

    current =
      case vm do
        %{^configurable => nil} -> %{}
        %{^configurable => struct} -> Map.from_struct(struct)
      end

    config =
      config
      |> Map.new()
      |> Map.merge(current, fn _, v1, _ ->
        v1
      end)
      |> Map.put(:applied?, false)
      |> then(&struct(module, &1))

    %{vm | configurable => config}
  end

  def configure(%Firecracker{}, invalid, _config) do
    raise ArgumentError, "invalid configuration key: #{inspect(invalid)}"
  end

  @addables [:drive, :network_interface, :pmem]
  @id_keys %{drive: :drive_id, network_interface: :iface_id, pmem: :id}

  # TODO: Somehow cannot update drive and network IDs

  @doc """
  Adds the given interface to the VM.

  Valid interfaces are:

    * `:drive` - Add a drive to the VM
    * `:network_interface` - Add a network interface to the VM
    * `:pmem` - Add a persistent memory device to the VM

  `id` must be a unique string key identifying the interface. If `id` already
  exists, the interface will be modified with the updated configuration. `id`
  overwrites Firecracker-specific identifiers you may set, e.g. `drive_id`,
  `iface_id`, and `id` respectively.

  See `Firecracker.Drive`, `Firecracker.NetworkInterface`, and `Firecracker.Pmem`
  for available device-specific configuration options.
  """
  @doc type: :configuration
  @spec add(t(), addable(), String.t(), keyword()) :: t()
  def add(%Firecracker{state: state} = vm, addable, id, config) when addable in @addables do
    module_name = Module.concat(Firecracker, Macro.camelize(Atom.to_string(addable)))
    model = struct(module_name, %{})
    id_key = @id_keys[addable]
    Firecracker.Model.validate_change!(model, Keyword.put(config, id_key, id), state)

    key = :"#{Atom.to_string(addable)}s"
    current = get_in(vm, [Access.key!(key)])

    config =
      config
      |> Map.new()
      |> Map.put(id_key, id)
      |> Map.put(:applied?, false)
      |> then(&struct(module_name, &1))

    %{vm | key => Map.put(current, id, config)}
  end

  def add(%Firecracker{}, invalid, _id, _config) do
    raise ArgumentError, "invalid configuration key: #{inspect(invalid)}"
  end

  @doc """
  Configures the given VM with the given metadata.

  This operation replaces all of the metadata currently present in
  the VM MMDS. If you'd like to add or update a single key, see
  `Firecracker.metadata/3`.

  Note this change is data-only. Changes are only applied after calling
  `Firecracker.start/1` or `Firecracker.apply/1`.
  """
  @doc type: :configuration
  @spec metadata(t(), map()) :: t()
  def metadata(%Firecracker{mmds: _} = vm, data) when is_map(data) do
    %{vm | mmds: %Firecracker.Mmds{data: data, applied?: false}}
  end

  @doc """
  Configures the given metadata `key` to have the given `value`.

  If `key` exists, the data is overwritten. If it does not, the key
  is created.

  Metadata is stored in the MicroVMs Metadata store and can be retrieved when
  the VM is running.

  Note this change is data-only. Changes are only applied after calling
  `Firecracker.start/1` or `Firecracker.apply/1`.
  """
  @doc type: :configuration
  @spec metadata(t(), String.t(), term()) :: t()
  def metadata(%Firecracker{mmds: mmds} = vm, key, value) do
    %{data: data} = meta = mmds || %Firecracker.Mmds{}
    %{vm | mmds: %{meta | applied?: false, data: Map.put(data, key, value)}}
  end

  @doc """
  Configures or updates the given metadata `key` with a default
  value or function.

  If `key` exists, the data is updated using `fun`, if it does not
  it is created with `value`.

  Metadata is stored in the MicroVMs Metadata store and can be retrieved when
  the VM is running.

  Note this change is data-only. Changes are only applied after calling
  `Firecracker.start/1` or `Firecracker.apply/1`.
  """
  @doc type: :configuration
  def metadata(%Firecracker{mmds: mmds} = vm, key, value, fun) do
    %{data: data} = meta = mmds || %Firecracker.Mmds{}
    %{vm | mmds: %{meta | applied?: false, data: Map.update(data, key, value, fun)}}
  end

  @doc """
  Sets the given Firecracker options.

  Options are applied at VM create time. Options that can be configured
  here map directly to CLI arguments that can be passed to the Firecracker
  binary.

  In addition to the CLI arguments, you may also configure the path to the
  Firecracker binary via the `:firecracker_path` argument.

  Note that these options may only be applied _before_ the VM has been created.
  Changes after creation are prohibited.

  Each option may take a function in-place of a value. The value will be computed
  at VM creation time.

  ## Options

    * `:api_sock` - Path of the unix socket to use for the VM API. Defaults
      to `"/tmp/firecracker.\#{System.unique_integer([:positive])}.sock"`.

    * `:boot_timer` - Whether or not to load boot timer device for logging elapsed
      time since InstanceStart command.

    * `:config_file` - Path to a file that contains the microVM configuration in JSON
      format. Note that setting this option will override any configurations you set.
      This is not recommended.

    * `:http_api_max_payload_size` - HTTP API request payload max size, in bytes.
      Defaults to 51200.

    * `:id` - MicroVM unique identifier. Defaults to `"anonymous-instance"`.

    * `:level` - Firecracker log level.

    * `:log_path` - Path to a fifo or file used for configuring the logger on startup.

    * `:metrics_path` - Path to a fifo or a file used for configuring the metrics
      on startup.

    * `:mmds_size_limit` - Mmds data store limit, in bytes.

    * `:module` - Set the logger module filter.

    * `:no_api` - Optional parameter which allows starting and using a microVM
      without an active API socket.

    * `:no_seccomp` - Optional parameter which allows starting and using a microVM
      without seccomp filtering. Not recommended.

    * `:parent_cpu_time_us` - Parent process CPU time (wall clock, microseconds).
      This parameter is optional.

    * `:seccomp_filter` - Optional parameter which allows specifying the path to a custom
      seccomp filter. For advanced users.

    * `:show_level` - Whether or not to output the level in the logs.

    * `:show_log_origin` - Whether or not to include the file path and line number of
      the log's origin.
    
    * `:start_time_cpu_us` - Process start CPU time (wall clock, microseconds).
      This parameter is optional.

    * `:start_time_us` - Process start time (wall clock, microseconds). This parameter
      is optional.
  """
  @doc type: :configuration
  @spec set_options(t(), keyword()) :: t()
  def set_options(vm, opts \\ [])

  def set_options(%Firecracker{state: :initial} = vm, opts) do
    Enum.reduce(opts, vm, fn {k, v}, vm ->
      Firecracker.set_option(vm, k, v)
    end)
  end

  def set_options(%Firecracker{state: state}, _opts) do
    raise ArgumentError, "vm options cannot be set after vm creation, vm state is #{state}"
  end

  @firecracker_options [:api_sock, :boot_timer, :config_file, :http_api_max_payload_size] ++
                         [:id, :level, :log_path, :metrics_path, :mmds_size_limit, :module] ++
                         [:no_api, :no_seccomp, :parent_cpu_time_us, :seccomp_filter] ++
                         [:show_level, :show_log_origin, :start_time_cpu_us, :start_time_us]

  @doc """
  Sets the given Firecracker option `key` with `value`.

  Options are applied at VM create time. Options that can be configured
  here map directly to CLI arguments that can be passed to the Firecracker
  binary.

  In addition to the CLI arguments, you may also configure the path to the
  Firecracker binary via the `:firecracker_path` argument.

  Note that these options may only be applied _before_ the VM has been created.
  Changes after creation are prohibited.

  ## Options

      * `:api_sock` - Path of the unix socket to use for the VM API. Defaults
        to `"/tmp/firecracker.\#{System.unique_integer([:positive])}.sock"`.

      * `:boot_timer` - Whether or not to load boot timer device for logging elapsed
        time since InstanceStart command.

      * `:config_file` - Path to a file that contains the microVM configuration in JSON
        format. Note that setting this option will override any configurations you set.
        This is not recommended.

      * `:http_api_max_payload_size` - Http API request payload max size, in bytes.
        Defaults to 51200.

      * `:id` - MicroVM unique identifier. Defaults to `"anonymous-instance"`.

      * `:level` - Firecracker log level.

      * `:log_path` - Path to a fifo or file used for configuring the logger on startup.

      * `:metrics_path` - Path to a fifo or a file used for configuring the metrics
        on startup.

      * `:mmds_size_limit` - Mmds data store limit, in bytes.

      * `:module` - Set the logger module filter.

      * `:no_api` - Optional parameter which allows starting and using a microVM
        without an active API socket.

      * `:no_seccomp` - Optional parameter which allows starting and using a microVM
        without seccomp filtering. Not recommended.

      * `:parent_cpu_time_us` - Parent process CPU time (wall clock, microseconds).
        This parameter is optional.

      * `:seccomp_filter` - Optional parameter which allows specifying the path to a custom
        seccomp filter. For advanced users.

      * `:show_level` - Whether or not to output the level in the logs.

      * `:show_log_origin` - Whether or not to include the file path and line number of
        the log's origin.
      
      * `:start_time_cpu_us` - Process start CPU time (wall clock, microseconds).
        This parameter is optional.

      * `:start_time_us` - Process start time (wall clock, microseconds). This parameter
        is optional.
  """
  @doc type: :configuration
  @spec set_option(t(), atom(), term()) :: t()
  def set_option(%Firecracker{state: :initial} = vm, :api_sock, sock) do
    %{vm | api_sock: sock}
  end

  def set_option(%Firecracker{state: :initial} = vm, :id, id) do
    %{vm | id: id}
  end

  def set_option(%Firecracker{state: :initial} = vm, :firecracker_path, path) do
    %{vm | firecracker_path: path}
  end

  def set_option(%Firecracker{state: :initial} = vm, :no_api, no_api) do
    %{vm | no_api: no_api}
  end

  def set_option(%Firecracker{state: :initial} = vm, :config_file, config_file) do
    %{vm | config_file: config_file}
  end

  def set_option(%Firecracker{state: :initial} = vm, key, value)
      when key in @firecracker_options do
    %{vm | options: Map.put(vm.options, key, value)}
  end

  def set_option(%Firecracker{state: :initial}, key, _) do
    raise ArgumentError, "invalid firecracker option #{key}"
  end

  def set_option(%Firecracker{state: state}, _key, _value) do
    raise ArgumentError, "vm options cannot be set after vm creation, vm state is #{state}"
  end

  @doc """
  Configures tracing for the VM's API requests.

  This function instruments the Req struct, enabling request/response
  tracing for all API calls made to the Firecracker API.

  The currently supported tracers are `:log` and `:file`. Custom function
  support is planned.
  """
  @doc type: :configuration
  @spec trace(t(), :logger | :file, keyword()) :: t()
  def trace(vm, tracer, opts \\ [])

  def trace(%Firecracker{req: nil} = vm, tracer, opts)
      when tracer in [:logger, :file] do
    # Store tracing configuration to be applied when VM starts
    %{vm | tracing: {tracer, opts}}
  end

  def trace(%Firecracker{req: req} = vm, :log, opts) do
    %{vm | req: Firecracker.Tracing.log(req, opts), tracing: {:logger, opts}}
  end

  def trace(%Firecracker{req: req} = vm, :file, opts) do
    %{vm | req: Firecracker.Tracing.log(req, opts), tracing: {:file, opts}}
  end

  # TODO: Support custom tracing!
  def trace(%Firecracker{}, invalid_tracer, _opts) do
    raise ArgumentError, "invalid tracer type: #{inspect(invalid_tracer)}"
  end

  ## Lifecycle

  @doc """
  Starts a new Firecracker VM with the given configuration.

  The Firecracker process will be attached to the `:process` key with
  the information about the running PID. This library does not do any
  automatic cleanup. Failure to stop the running VM will result in
  Zombie processes.

  Note starting the VM is not equivalent to booting the VM. See `Firecracker.boot/1`
  for details on booting.
  """
  @doc type: :lifecycle
  @spec start(t()) :: t()
  def start(%Firecracker{state: :initial, id: id, config_file: config_file} = vm) do
    %{binary: binary, args: args, api_sock: sock, config: config} = Firecracker.dry_run(vm)

    {args, config_file} =
      if is_nil(sock) and is_nil(config_file) do
        path = Path.join([System.tmp_dir(), "#{id}.config.json"])
        File.write!(path, :json.encode(config))
        {["--config-file", path | args], path}
      else
        {args, config_file}
      end

    p = Px.spawn!(binary, args)

    case wait_for_process(p, 100) do
      :ok ->
        req = Req.new(base_url: "http://localhost", unix_socket: sock)

        req =
          case vm.tracing do
            {:logger, opts} -> Firecracker.Tracing.log(req, opts)
            {:file, opts} -> Firecracker.Tracing.file(req, opts)
            nil -> req
          end

        vm = %{
          vm
          | api_sock: sock,
            process: p,
            config_file: config_file,
            state: :started,
            req: req
        }

        Firecracker.apply(vm)

      {:error, reason} ->
        if Px.alive?(p) do
          p
          |> Px.signal!(:sigterm)
          |> Px.wait()
        end

        if config_file, do: File.rm_rf!(config_file)
        if sock, do: File.rm_rf!(sock)

        raise "Failed to start Firecracker: #{inspect(reason)}"
    end
  end

  def start(%Firecracker{state: :started} = vm), do: vm

  def start(%Firecracker{state: state}) do
    raise ArgumentError, "unable to start VM which is in #{inspect(state)} state"
  end

  defp wait_for_process(process, timeout_ms) do
    Process.sleep(timeout_ms)

    if Px.alive?(process) do
      :ok
    else
      {:error, :process_died}
    end
  end

  @apply_order [:drives, :network_interfaces, :pmems, :mmds | @configurables]

  @doc """
  Applies configuration changes to the VM.

  Firecracker struct keeps track of un-applied configuration
  changes and applies them using the running REST API.

  The struct will also keep track of any errors accumulated
  during application of changes. If a particular configuration change
  results in an error, the field will be left in an "un-applied" state,
  and the error will be prepended to the `:errors` field of the VM
  struct.
  """
  @doc type: :configuration
  @spec apply(t()) :: t()
  def apply(%Firecracker{req: req, state: state} = vm)
      when state in [:started, :running, :paused, :shutdown] do
    Enum.reduce(@apply_order, vm, fn key, acc ->
      case vm do
        %{^key => nil} ->
          acc

        %{^key => %{applied?: true}} ->
          acc

        %{^key => %{} = val} when map_size(val) == 0 ->
          acc

        %{^key => val} ->
          do_apply(req, state, key, val, acc)
      end
    end)
  end

  defp do_apply(req, state, key, value, acc) do
    fun =
      case state do
        state when state in [:initial, :started] -> :put
        _ -> :patch
      end

    api_update(req, key, value, fun, acc)
  end

  defp api_update(req, key, value, fun, vm) when key in [:drives, :network_interfaces, :pmems] do
    value
    |> Enum.reject(fn {_, v} -> v.applied? end)
    |> Enum.reduce(vm, fn {id, val}, vm ->
      case apply(Client, fun, [req, val]) do
        {:ok, _} ->
          %{vm | key => Map.update!(value, id, fn cfg -> %{cfg | applied?: true} end)}

        {:error, error} ->
          %{vm | errors: [{key, error} | vm.errors]}
      end
    end)
  end

  defp api_update(req, key, value, fun, vm) do
    case apply(Client, fun, [req, value]) do
      {:ok, _} ->
        %{vm | key => %{value | applied?: true}}

      {:error, error} ->
        %{vm | errors: [{key, error} | vm.errors]}
    end
  end

  defp to_api_key(key) do
    key
    |> Atom.to_string()
    |> String.split("_")
    |> Enum.join("-")
  end

  @doc """
  Boots a Firecracker VM.

  This method invokes the `InstanceStart` action on a created VM which
  kicks off the boot process. The VM must already be in a `:started`
  state.

  Attempting to start an already running VM is a no-op.
  """
  @doc type: :lifecycle
  @spec boot(t()) :: t()
  def boot(%Firecracker{req: req, state: state} = vm) when state in [:started, :shutdown] do
    with {:ok, _} <- Client.create_sync_action(req, %{action_type: "InstanceStart"}) do
      %{vm | state: :running}
    end
  end

  def boot(%Firecracker{state: :running} = vm), do: vm

  def boot(%Firecracker{state: state}) do
    raise ArgumentError, "unable to boot VM which is in state #{inspect(state)}"
  end

  @doc """
  Stops a Firecracker VM.

  Stopping the VM sends `SIGTERM` to the running Firecracker process. You
  will not be able to resume from this state.

  Attempting to stop an already exited VM is a no-op.
  """
  @doc type: :lifecycle
  @spec stop(t()) :: t()
  def stop(%Firecracker{process: %Px{} = p, state: state} = vm)
      when state in [:started, :running, :paused] do
    p = Px.wait(Px.signal!(p, :sigterm))
    cleanup_files!(vm)
    %{vm | process: p, state: :exited}
  end

  def stop(%Firecracker{state: :exited} = vm), do: vm

  def stop(%Firecracker{state: state}) do
    raise ArgumentError, "unable to stop VM which is already in state #{inspect(state)}"
  end

  defp cleanup_files!(%Firecracker{} = vm) do
    %{
      config_file: config,
      api_sock: api_sock,
      vsock: vsock,
      metrics: metrics,
      serial: serial
    } = vm

    if api_sock, do: File.rm_rf!(api_sock)
    if config, do: File.rm_rf!(config)

    with %{uds_path: path} when is_binary(path) <- vsock do
      File.rm_rf!(path)
    end

    with %{metrics_path: path} when is_binary(path) <- metrics do
      File.rm_rf!(path)
    end

    with %{output_path: path} when is_binary(path) <- serial do
      File.rm_rf!(path)
    end
  end

  @doc """
  Pauses a Firecracker VM.

  Attempting to pause an already paused VM is a no-op.
  """
  @doc type: :lifecycle
  @spec pause(t()) :: t()
  def pause(%Firecracker{req: req, state: :running} = vm) do
    with {:ok, _} <- Client.patch_vm(req, %{state: "Paused"}) do
      %{vm | state: :paused}
    end
  end

  def pause(%Firecracker{state: :paused} = vm), do: vm

  def pause(%Firecracker{state: state}) do
    raise ArgumentError, "unable to pause VM which is in state #{inspect(state)}"
  end

  @doc """
  Resumes a paused Firecracker VM.

  Attempting to resume an already running VM is a no-op.
  """
  @doc type: :lifecycle
  @spec resume(t()) :: t()
  def resume(%Firecracker{req: req, state: :paused} = vm) do
    with {:ok, _} <- Client.patch_vm(req, %{state: "Resumed"}) do
      %{vm | state: :running}
    end
  end

  def resume(%Firecracker{state: :running} = vm), do: vm

  def resume(%Firecracker{state: state}) do
    raise ArgumentError, "unable to resume VM which is already in state #{inspect(state)}"
  end

  @doc """
  Shutsdown a Firecracker VM.

  Attempting to shutdown an already shutdown VM is a no-op.
  """
  @doc type: :lifecycle
  @spec shutdown(t()) :: t()
  def shutdown(%Firecracker{req: req, state: :running} = vm) do
    with {:ok, _} <- Client.create_sync_action(req, %{action_type: "SendCtrlAltDel"}) do
      %{vm | state: :shutdown}
    end
  end

  def shutdown(%Firecracker{state: :shutdown} = vm), do: vm

  def shutdown(%Firecracker{state: state}) do
    raise ArgumentError, "unable to shutdown VM which is already in state #{inspect(state)}"
  end

  @doc """
  Flushes metrics to the configured metrics file or pipe.

  This triggers an immediate flush of all accumulated metrics to the metrics destination
  configured via the metrics_path option. Useful for ensuring metrics are written before
  taking snapshots or for periodic metrics collection.

  Returns the updated VM struct.
  """
  @doc type: :configuration
  @spec flush_metrics(t()) :: t()
  def flush_metrics(%Firecracker{req: req, state: state} = vm)
      when state in [:started, :running, :paused, :shutdown] do
    with {:ok, _} <- Client.create_sync_action(req, %{action_type: "FlushMetrics"}) do
      vm
    end
  end

  def flush_metrics(%Firecracker{state: state}) do
    raise ArgumentError, "unable to flush metrics for VM in state #{inspect(state)}"
  end

  ## Snapshots

  @doc """
  Creates a snapshot of the Firecracker VM.

  The VM must be in a `:paused` state before creating the snapshot.

  Returns a `%Firecracker.Snapshot{}`

  ## Options

      * `:mem_file_path` - Path to the file that will contain the guest memory.
        This is a required argument.

      * `:path` - Path to the file that will contain the microVM state.
        This is a required argument.

      * `:type` - Type of snapshot to create. Can be either `:full` or
        `:diff`. Defaults to `:full`
  """
  @doc type: :snapshot
  @spec snapshot(t(), keyword()) :: Firecracker.Snapshot.t()
  def snapshot(vm, opts \\ [])

  def snapshot(%Firecracker{req: req, state: :paused}, opts) do
    opts =
      Keyword.validate!(opts, [
        :mem_file_path,
        :snapshot_path,
        snapshot_type: :full
      ])

    mem_file_path = opts[:mem_file_path] || raise ArgumentError, "mem_file_path is required"
    snapshot_path = opts[:path] || raise ArgumentError, "snapshot_path is required"
    snapshot_type = opts[:type]

    attrs = %{
      mem_file_path: mem_file_path,
      snapshot_path: snapshot_path,
      snapshot_type: snapshot_type
    }

    json_args = Map.update!(attrs, :snapshot_type, &snapshot_type/1)

    with {:ok, _} <- Client.create_snapshot(req, json_args) do
      struct(Firecracker.Snapshot, attrs)
    end
  end

  def snapshot(%Firecracker{state: state}, _opts) do
    raise ArgumentError, "unable to snapshot VM which is in #{inspect(state)} state"
  end

  @doc """
  Loads a Firecracker VM from a snapshot.

  The VM must be in a started state, but not yet booted. The
  snapshot must be a valid `%Firecracker.Snapshot{}` struct.

  See `Firecracker.Snapshot` for information on configuring snapshots.
  """
  @doc type: :snapshot
  @spec load(t(), Firecracker.Snapshot.t()) :: t()
  def load(
        %Firecracker{req: req, state: :started} = vm,
        %Firecracker.Snapshot{resume_vm: resume?} = snapshot
      ) do
    config =
      snapshot
      |> Map.from_struct()
      |> Enum.reject(fn {_, v} -> is_nil(v) or map_size(v) == 0 end)
      |> Map.new(fn
        {:snapshot_type, v} -> {:snapshot_type, snapshot_type(v)}
        {:network_overrides, v} -> {:network_overrides, network_overrides(v)}
        {k, v} -> {k, v}
      end)

    with {:ok, _} <- Client.load_snapshot(req, config) do
      if resume? do
        %{vm | state: :running}
      else
        vm
      end
    end
  end

  def load(%Firecracker{state: state}, _snapshot) do
    raise ArgumentError, "unable to load snapshot for VM which is in state #{inspect(state)}"
  end

  defp snapshot_type(:full), do: "Full"
  defp snapshot_type(:diff), do: "Diff"

  defp network_overrides(overrides) do
    Enum.map(overrides, fn {k, v} -> %{"iface_id" => k, "host_dev_name" => v} end)
  end

  ## Inspection

  @doc """
  Describes the changes that will be applied on start or application.

  Dry-run will return a map with the following keys:

    * `:binary` - path to the binary used to run the Firecracker process
    * `:args` - exact CLI args used to start the Firecracker process
    * `:api_sock` - path to the API socket, unless disabled
    * `:config` - configuration changes that will be applied on the next
      call to `start/1` or `apply/1`.
  """
  @doc type: :inspection
  @spec dry_run(t()) :: map()
  def dry_run(%Firecracker{no_api: no_api, api_sock: sock, state: state} = vm) do
    config =
      Enum.reduce(@apply_order, %{}, fn key, acc ->
        case vm do
          %{^key => nil} ->
            acc

          %{^key => %{applied?: true}} ->
            acc

          %{^key => %{} = val} when map_size(val) == 0 ->
            acc

          %{^key => val} ->
            fun =
              case state do
                state when state in [:initial, :started] -> :put
                _ -> :patch
              end

            dry_update(key, val, fun, acc)
        end
      end)

    {binary, args} = to_firecracker_cmd(vm)
    sock = if no_api, do: nil, else: sock

    %{
      binary: binary,
      args: args,
      config: config,
      api_sock: sock
    }
  end

  defp dry_update(
         :balloon,
         %Firecracker.Balloon{stats_polling_interval_s: interval} = value,
         :patch,
         acc
       )
       when not is_nil(interval) do
    update =
      value
      |> Firecracker.Model.patch()
      |> Map.put("stats_polling_interval_s", interval)

    Map.put(acc, to_api_key(:balloon), update)
  end

  defp dry_update(key, value, fun, acc) when key in [:drives, :network_interfaces, :pmems] do
    values =
      value
      |> Enum.reject(fn {_, v} -> v.applied? end)
      |> Enum.map(&apply(Firecracker.Model, fun, [elem(&1, 1)]))

    Map.put(acc, to_api_key(key), values)
  end

  defp dry_update(key, value, fun, acc) do
    Map.put(acc, to_api_key(key), apply(Firecracker.Model, fun, [value]))
  end

  @doc """
  Describes information about the given Firecracker instance.

  The instance must be in `:started`, `:running`, or `:paused` state
  for this invocation to work.
  """
  @doc type: :inspection
  @spec describe(t()) :: map()
  def describe(%Firecracker{req: req, state: state})
      when state in [:shutdown, :started, :running, :paused] do
    with {:ok, response} <- Client.describe(req, :instance) do
      response
    end
  end

  def describe(%Firecracker{state: state}) do
    raise ArgumentError, "unable to describe VM which is in state #{inspect(state)}"
  end

  @describables [
    :balloon,
    :balloon_statistics,
    :machine_config,
    :mmds,
    :vm_config
  ]

  @doc """
  Describes information about the given Firecracker instance
  configuration key.

  The instance must be in `:started`, `:running`, or `:paused` state
  for this invocation to work.

  Valid keys to describe are:

    * `:balloon` - returns information about the balloon device configuration
    * `:balloon_statistics` - returns information about balloon device statistics
    * `:machine_config` - returns information about the machine configuration
    * `:mmds` - returns information about the mmds data content
    * `:vm_config` - returns information about the full vm configuration
  """
  @doc type: :inspection
  @spec describe(t(), describable()) :: map()
  def describe(%Firecracker{req: req, state: state}, key)
      when state in [:shutdown, :started, :running, :paused] and key in @describables do
    with {:ok, response} <- Client.describe(req, key) do
      response
    end
  end

  def describe(%Firecracker{state: state}, key) do
    raise ArgumentError,
          "unable to describe #{inspect(key)} for VM which is in state #{inspect(state)}"
  end

  ## Jailer

  @doc """
  Configures the given VM to run in the context of the
  [Firecracker Jailer](https://github.com/firecracker-microvm/firecracker/blob/main/docs/jailer.md).

  The VM must be in an `:initial` state.

  You must configure the `uid` and `gid` options. See `Firecracker.cgroup/3`
  and `Firecracker.resource_limit/3` for configuring cgroups and resource
  limits on the jailer.

  ## Options

    * `:uid` - uid the jailer switches to in order to exec target binary
    * `:gid` - gid the jailer switches to in order to exec target binary
    * `:parent_cgroup` - allows the placement of microvm cgroups in custom nested hierarchies
    * `:cgroup_version` - selects the type of cgroup hierarchy to use for creation of cgroups
    * `:chroot_base_dir` - the base folder where chroot jails are built. Defaults to
      `/srv/jailer`
    * `:netns` - path to a network namespace handle for the jailer to use to join
      the associated network namespace.
  """
  @doc type: :jailer
  @spec jail(t(), keyword()) :: t()
  def jail(firecracker, opts \\ [])

  def jail(%Firecracker{state: :initial} = vm, opts) do
    opts = Firecracker.Jailer.validate_options!(opts)

    jailer =
      opts
      |> Map.new()
      |> then(&struct(Firecracker.Jailer, &1))

    %{vm | jailer: jailer}
  end

  def jail(%Firecracker{state: state}, _opts) do
    raise ArgumentError, "cannot apply jailer when VM is in state #{inspect(state)}"
  end

  @doc """
  Configures the given VM to run with the given cgroup value.

  The VM must be in an `:initial` state with a jailer configured.
  """
  @doc type: :jailer
  @spec cgroup(t(), String.t(), term()) :: t()
  def cgroup(
        %Firecracker{state: :initial, jailer: %Firecracker.Jailer{} = jailer} = vm,
        cgroup_file,
        value
      ) do
    cgroups = jailer.cgroups || %{}
    %{vm | jailer: %{jailer | cgroups: Map.put(cgroups, cgroup_file, value)}}
  end

  def cgroup(%Firecracker{state: :initial, jailer: nil}, _cgroup_file, _value) do
    raise ArgumentError, "unable to configure cgroup on VM with no jailer present"
  end

  def cgroup(%Firecracker{state: state}, _cgroup_file, _value) do
    raise ArgumentError, "cannot apply cgroup when VM is in state #{inspect(state)}"
  end

  @doc """
  Configures the given VM to run with the given resource limits.

  The VM must be in an `:initial` state with a jailer configured.

  Valid resources are:

    * `"fsize"` - maximum size in bytes for files created by the process
    * `"no-file"` - value one greater than the maximum file descriptor number
      that can be opened by this process.
  """
  @doc type: :jailer
  @spec resource_limit(t(), String.t(), term()) :: t()
  def resource_limit(
        %Firecracker{state: :initial, jailer: %Firecracker.Jailer{} = jailer} = vm,
        resource,
        value
      ) do
    resource_limits = jailer.resource_limits || %{}
    %{vm | jailer: %{jailer | resource_limits: Map.put(resource_limits, resource, value)}}
  end

  def resource_limit(%Firecracker{state: :initial, jailer: nil}, _resource, _value) do
    raise ArgumentError, "unable to configure resource limit on VM with no jailer present"
  end

  def resource_limit(%Firecracker{state: state}, _resource, _value) do
    raise ArgumentError, "cannot apply resource limit when VM is in state #{inspect(state)}"
  end

  ## Helpers

  @doc """
  Return the Firecracker binary for the given VM.
  """
  @doc type: :helper
  @spec which(t()) :: String.t()
  def which(%Firecracker{firecracker_path: path}) do
    path || which()
  end

  @doc """
  Returns the default Firecracker binary as given by the environment
  or default value.
  """
  @doc type: :helper
  @spec which() :: String.t()
  def which() do
    env(:firecracker_path) || default_firecracker_path()
  end

  @doc """
  Returns the Firecracker version for the VM.

  If the `:firecracker_path` is not set for the VM, this will use
  the environment path, or the default path.
  """
  @doc type: :helper
  @spec version(t()) :: String.t()
  def version(%Firecracker{firecracker_path: path}) do
    binary = path || which()
    firecracker(binary, "--version")
  end

  @doc """
  Returns the Firecracker version using the environment Firecracker
  binary, or the default binary.
  """
  @doc type: :helper
  @spec version() :: String.t()
  def version() do
    firecracker(which(), "--version")
  end

  @doc """
  Returns the Firecracker snapshot version for the VM.

  If the `:firecracker_path` is not set for the VM, this will use
  the environment path, or the default path.
  """
  @doc type: :helper
  @spec snapshot_version(t()) :: String.t()
  def snapshot_version(%Firecracker{firecracker_path: path}) do
    binary = path || which()
    firecracker(binary, "--snapshot-version")
  end

  @doc """
  Returns the Firecracker snapshot version using the environment Firecracker
  binary, or the default binary.
  """
  @doc type: :helper
  @spec snapshot_version() :: String.t()
  def snapshot_version() do
    firecracker(which(), "--snapshot-version")
  end

  defp to_firecracker_cmd(
         %Firecracker{jailer: %Firecracker.Jailer{jailer_path: path} = jailer} = vm
       ) do
    path = path || default_jailer_path()
    vm_args = parse_cli_args(vm, false)
    jailer_args = parse_jailer_args(vm, jailer)
    args = jailer_args ++ ["--"] ++ vm_args
    {path, args}
  end

  defp to_firecracker_cmd(%Firecracker{} = vm) do
    args = parse_cli_args(vm, true)
    {which(vm), args}
  end

  defp parse_cli_args(
         %Firecracker{
           no_api: no_api,
           api_sock: sock,
           config_file: config_file,
           id: id,
           options: options
         },
         include_id?
       ) do
    args =
      Enum.reduce(options, [], fn
        {:boot_timer, true}, args ->
          [{"--boot-timer"} | args]

        {:http_api_max_payload_size, size}, args ->
          [{"--http-api-max-payload-size", option(size)} | args]

        {:level, level}, args ->
          [{"--level", option(level)} | args]

        {:log_path, path}, args ->
          [{"--log-path", option(path)} | args]

        {:metrics_path, path}, args ->
          [{"--metrics-path", option(path)} | args]

        {:metadata, path}, args ->
          [{"--metadata", option(path)} | args]

        {:mmds_size_limit, limit}, args ->
          [{"--mmds-size-limit", option(limit)} | args]

        {:module, mod}, args ->
          [{"--module", option(mod)} | args]

        {:no_seccomp, true}, args ->
          [{"--no-seccomp"} | args]

        {:enable_pci, true}, args ->
          [{"--enable-pci"} | args]

        {:parent_cpu_time_us, time}, args ->
          [{"--parent-cpu-time-us", option(time)} | args]

        {:seccomp_filter, filter}, args ->
          [{"--seccomp-filter", option(filter)} | args]

        {:show_level, true}, args ->
          [{"--show-level"} | args]

        {:show_log_origin, true}, args ->
          [{"--show-log-origin"} | args]

        {:start_time_cpu_us, time}, args ->
          [{"--start-time-cpu-us", option(time)} | args]

        {:start_time_us, time}, args ->
          [{"--start-time-us", option(time)} | args]

        _, args ->
          args
      end)

    id = option(id)
    sock = option(sock)

    args = if include_id?, do: [{"--id", id} | args], else: args
    args = if no_api, do: [{"--no-api"} | args], else: [{"--api-sock", sock} | args]
    args = if config_file, do: [{"--config-file", config_file} | args], else: args

    args
    |> Enum.sort_by(&elem(&1, 0), :asc)
    |> Enum.flat_map(&Tuple.to_list/1)
  end

  defp parse_jailer_args(%Firecracker{id: id} = vm, %Firecracker.Jailer{} = jailer) do
    args =
      jailer
      |> Map.from_struct()
      |> Enum.reject(fn {_, v} -> is_nil(v) end)
      |> Enum.reject(fn
        {_, %{} = v} -> Enum.empty?(v)
        _ -> false
      end)
      |> Enum.reduce([], fn
        {:uid, uid}, args ->
          [{"--uid", option(uid)} | args]

        {:gid, gid}, args ->
          [{"--gid", option(gid)} | args]

        {:parent_cgroup, parent}, args ->
          [{"--parent-cgroup", option(parent)} | args]

        {:netns, netns}, args ->
          [{"--netns", option(netns)} | args]

        {:new_pid_ns, new_pid_ns}, args ->
          [{"--new-pid-ns", option(new_pid_ns)} | args]

        {:cgroup_version, cgroup_version}, args ->
          [{"--cgroup-version", option(cgroup_version)} | args]

        {:chroot_base_dir, chroot_base_dir}, args ->
          [{"--chroot-base-dir", option(chroot_base_dir)} | args]

        {:cgroups, cgroups}, args ->
          cgroups = Enum.map(cgroups, fn {k, v} -> {"--cgroup", "#{k}=#{v}"} end)
          cgroups ++ args

        {:resource_limits, resources}, args ->
          resource_limits =
            Enum.map(resources, fn {k, v} -> {"--resource-limit", "#{k}=#{v}"} end)

          resource_limits ++ args

        {:daemonize, true}, args ->
          [{"--daemonize"} | args]

        _, args ->
          args
      end)

    args = [{"--id", id} | args]
    args = [{"--exec-file", which(vm)} | args]

    args
    |> Enum.sort_by(&elem(&1, 0), :asc)
    |> Enum.flat_map(&Tuple.to_list/1)
  end

  defp option(val) when is_function(val), do: val.()
  defp option(val) when is_integer(val), do: "#{val}"
  defp option(val) when is_atom(val), do: Atom.to_string(val)
  defp option(val) when is_binary(val), do: val

  defp default_api_sock, do: "/tmp/firecracker.#{System.unique_integer([:positive])}.sock"
  defp default_id, do: "anonymous-instance-#{System.unique_integer([:positive])}"

  defp default_firecracker_path,
    do: Path.join([System.user_home(), ".firecracker", "bin", "firecracker"])

  defp default_jailer_path,
    do: Path.join([System.user_home(), ".firecracker", "bin", "jailer"])

  defp firecracker(binary, flags) when is_binary(flags) or is_list(flags) do
    case System.cmd(binary, List.wrap(flags)) do
      {out, 0} ->
        out

      {out, exit_code} ->
        raise "exec error (#{exit_code}): #{out}"
    end
  end

  defp env(key), do: Application.get_env(:firecracker, __MODULE__)[key]
end

defimpl Inspect, for: Firecracker do
  import Inspect.Algebra

  def inspect(%Firecracker{} = vm, opts) do
    fields =
      [
        id: vm.id,
        state: vm.state,
        api_sock: vm.api_sock,
        pid: get_pid(vm.process)
      ]
      |> maybe_add_jailed(vm.jailer)
      |> maybe_add_errors(vm.errors)

    container_doc("#Firecracker<", fields, ">", opts, &field_to_algebra/2,
      break: :strict,
      separator: ","
    )
  end

  defp get_pid(%Px{pid: pid}), do: pid
  defp get_pid(_), do: nil

  defp maybe_add_jailed(fields, %Firecracker.Jailer{}), do: fields ++ [jailed: true]
  defp maybe_add_jailed(fields, _), do: fields

  defp maybe_add_errors(fields, [_ | _] = errors), do: fields ++ [errors: length(errors)]
  defp maybe_add_errors(fields, _), do: fields

  defp field_to_algebra({key, value}, opts) do
    concat([
      to_string(key),
      ": ",
      to_doc(value, opts)
    ])
  end
end
