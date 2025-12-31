defmodule FirecrackerTest do
  use ExUnit.Case, async: false

  setup do
    pid = self()
    on_exit(fn -> TempFiles.cleanup(pid) end)
    :ok
  end

  describe "new/1" do
    test "creates a new %Firecracker{} struct with default values" do
      assert %Firecracker{} = Firecracker.new()
    end

    test "creates a new %Firecracker{} struct with options set" do
      assert %Firecracker{api_sock: "/tmp/foo.sock"} = Firecracker.new(api_sock: "/tmp/foo.sock")
    end

    test "sets a default ID if user does not provide one" do
      assert %Firecracker{id: "anonymous-instance-" <> _} = Firecracker.new()
    end

    test "sets a default socket if user does not provide one" do
      assert %Firecracker{api_sock: "/tmp/firecracker." <> _} = Firecracker.new()
    end

    test "overrides default ID if set" do
      assert %Firecracker{id: "foo"} = Firecracker.new(id: "foo")
    end

    test "overrides default socket if set" do
      assert %Firecracker{api_sock: "/tmp/foo"} = Firecracker.new(api_sock: "/tmp/foo")
    end
  end

  describe "set_option/3" do
    test "updates :api_sock in the firecracker struct" do
      vm =
        Firecracker.new()
        |> Firecracker.set_option(:api_sock, "/tmp/firecracker.sock")

      assert %Firecracker{api_sock: "/tmp/firecracker.sock"} = vm
    end

    test "updates :id in the firecracker struct" do
      vm =
        Firecracker.new()
        |> Firecracker.set_option(:id, "my-id")

      assert %Firecracker{id: "my-id"} = vm
    end

    test "updates :firecracker_path in firecracker struct" do
      vm =
        Firecracker.new()
        |> Firecracker.set_option(:firecracker_path, "/usr/local/bin/firecracker")

      assert %Firecracker{firecracker_path: "/usr/local/bin/firecracker"} = vm
    end

    test "updates every other cli option in :options" do
      vm =
        Firecracker.new()
        |> Firecracker.set_option(:no_api, true)
        |> Firecracker.set_option(:http_api_max_payload_size, 50000)
        |> Firecracker.set_option(:start_time_us, 100)

      assert %Firecracker{
               no_api: true,
               options: %{start_time_us: 100, http_api_max_payload_size: 50000}
             } = vm
    end

    test "raises on invalid option" do
      assert_raise ArgumentError, ~r/invalid firecracker option/, fn ->
        Firecracker.new()
        |> Firecracker.set_option(:foo, 1)
      end
    end

    test "raises if vm is not in initial state" do
      assert_raise ArgumentError, ~r/vm options cannot be set after vm creation/, fn ->
        vm = Firecracker.new()
        vm = %{vm | state: :running}

        Firecracker.set_option(vm, :id, "my-id")
      end
    end
  end

  describe "set_options/2" do
    test "updates multiple values in options" do
      vm =
        Firecracker.new()
        |> Firecracker.set_options(no_api: true, no_seccomp: true)

      assert %Firecracker{no_api: true, options: %{no_seccomp: true}} = vm
    end

    test "updates multiple values in struct" do
      vm =
        Firecracker.new()
        |> Firecracker.set_options(api_sock: "fire.sock", id: "my-id")

      assert %Firecracker{api_sock: "fire.sock", id: "my-id"} = vm
    end

    test "updates multiple values in both struct nad options" do
      vm =
        Firecracker.new()
        |> Firecracker.set_options(api_sock: "fire.sock", no_seccomp: true)

      assert %Firecracker{api_sock: "fire.sock", options: %{no_seccomp: true}} = vm
    end

    test "raises if vm is not in initial state" do
      assert_raise ArgumentError, ~r/vm options cannot be set after vm creation/, fn ->
        vm = Firecracker.new()
        vm = %{vm | state: :running}

        Firecracker.set_options(vm, id: "my-id", api_sock: "/tmp/foo")
      end
    end

    test "raises on invalid option" do
      assert_raise ArgumentError, ~r/invalid firecracker option/, fn ->
        Firecracker.new()
        |> Firecracker.set_options(id: "foo", foo: "bar")
      end
    end
  end

  describe "configure/3 pre-boot data only changes" do
    test "configures a balloon device" do
      vm =
        Firecracker.new()
        |> Firecracker.configure(:balloon, amount_mib: 100, deflate_on_oom: true)

      assert %Firecracker{balloon: %Firecracker.Balloon{} = balloon} = vm
      assert %Firecracker.Balloon{amount_mib: 100, deflate_on_oom: true} = balloon
    end

    test "enforces required keys on balloon device" do
      assert_raise NimbleOptions.ValidationError, ~r/required :amount_mib option not found/, fn ->
        Firecracker.new()
        |> Firecracker.configure(:balloon, deflate_on_oom: true)
      end

      assert_raise NimbleOptions.ValidationError,
                   ~r/required :deflate_on_oom option not found/,
                   fn ->
                     Firecracker.new()
                     |> Firecracker.configure(:balloon, amount_mib: 100)
                   end
    end

    test "enforces types for balloon devices" do
      assert_raise NimbleOptions.ValidationError, ~r/invalid value for :amount_mib/, fn ->
        Firecracker.new()
        |> Firecracker.configure(:balloon, amount_mib: "not an integer", deflate_on_oom: true)
      end

      assert_raise NimbleOptions.ValidationError, ~r/invalid value for :deflate_on_oom/, fn ->
        Firecracker.new()
        |> Firecracker.configure(:balloon, amount_mib: 100, deflate_on_oom: "not a boolean")
      end

      assert_raise NimbleOptions.ValidationError,
                   ~r/invalid value for :stats_polling_interval_s/,
                   fn ->
                     Firecracker.new()
                     |> Firecracker.configure(:balloon,
                       amount_mib: 100,
                       deflate_on_oom: true,
                       stats_polling_interval_s: "not an integer"
                     )
                   end
    end

    test "configures a boot source" do
      vm =
        Firecracker.new()
        |> Firecracker.configure(:boot_source, kernel_image_path: "./vmlinux")

      assert %Firecracker{boot_source: %Firecracker.BootSource{} = boot_source} = vm
      assert %Firecracker.BootSource{kernel_image_path: "./vmlinux"} = boot_source
    end

    test "enforces required keys for boot source" do
      assert_raise NimbleOptions.ValidationError,
                   ~r/required :kernel_image_path option not found/,
                   fn ->
                     Firecracker.new()
                     |> Firecracker.configure(:boot_source, boot_args: "console=ttyS0")
                   end
    end

    test "enforces types for boot source" do
      assert_raise NimbleOptions.ValidationError, ~r/invalid value for :kernel_image_path/, fn ->
        Firecracker.new()
        |> Firecracker.configure(:boot_source, kernel_image_path: 123)
      end

      assert_raise NimbleOptions.ValidationError, ~r/invalid value for :boot_args/, fn ->
        Firecracker.new()
        |> Firecracker.configure(:boot_source, kernel_image_path: "./vmlinux", boot_args: 123)
      end

      assert_raise NimbleOptions.ValidationError, ~r/invalid value for :initrd_path/, fn ->
        Firecracker.new()
        |> Firecracker.configure(:boot_source, kernel_image_path: "./vmlinux", initrd_path: 123)
      end
    end

    test "configures cpu configuration" do
      vm =
        Firecracker.new()
        |> Firecracker.configure(:cpu_config, kvm_capabilities: ["!56"])

      assert %Firecracker{cpu_config: %Firecracker.CpuConfig{} = cpu_config} = vm
      assert %Firecracker.CpuConfig{kvm_capabilities: ["!56"]} = cpu_config
    end

    test "configures the logger" do
      vm =
        Firecracker.new()
        |> Firecracker.configure(:logger, level: "Info")

      assert %Firecracker{logger: %Firecracker.Logger{} = logger} = vm
      assert %Firecracker.Logger{level: "Info"} = logger
    end

    test "configures machine configuration" do
      vm =
        Firecracker.new()
        |> Firecracker.configure(:machine_config, vcpu_count: 1, mem_size_mib: 1000)

      assert %Firecracker{machine_config: %Firecracker.MachineConfig{} = machine_config} = vm
      assert %Firecracker.MachineConfig{vcpu_count: 1, mem_size_mib: 1000} = machine_config
    end

    test "enforces required keys for machine config" do
      assert_raise NimbleOptions.ValidationError,
                   ~r/required :mem_size_mib option not found/,
                   fn ->
                     Firecracker.new()
                     |> Firecracker.configure(:machine_config, vcpu_count: 1)
                   end

      assert_raise NimbleOptions.ValidationError, ~r/required :vcpu_count option not found/, fn ->
        Firecracker.new()
        |> Firecracker.configure(:machine_config, mem_size_mib: 1000)
      end
    end

    test "enforces types for machine config" do
      assert_raise NimbleOptions.ValidationError, ~r/invalid value for :vcpu_count/, fn ->
        Firecracker.new()
        |> Firecracker.configure(:machine_config,
          vcpu_count: "not an integer",
          mem_size_mib: 1000
        )
      end

      assert_raise NimbleOptions.ValidationError, ~r/invalid value for :mem_size_mib/, fn ->
        Firecracker.new()
        |> Firecracker.configure(:machine_config, vcpu_count: 1, mem_size_mib: "not an integer")
      end

      assert_raise NimbleOptions.ValidationError, ~r/invalid value for :smt/, fn ->
        Firecracker.new()
        |> Firecracker.configure(:machine_config,
          vcpu_count: 1,
          mem_size_mib: 1000,
          smt: "not a boolean"
        )
      end

      assert_raise NimbleOptions.ValidationError, ~r/invalid value for :track_dirty_pages/, fn ->
        Firecracker.new()
        |> Firecracker.configure(:machine_config,
          vcpu_count: 1,
          mem_size_mib: 1000,
          track_dirty_pages: "not a boolean"
        )
      end
    end

    test "configures mmds configuration" do
      vm =
        Firecracker.new()
        |> Firecracker.configure(:mmds_config,
          ipv4_address: "169.254.169.254",
          network_interfaces: ["eth0"]
        )

      assert %Firecracker{mmds_config: %Firecracker.MmdsConfig{} = mmds_config} = vm

      assert %Firecracker.MmdsConfig{
               ipv4_address: "169.254.169.254",
               network_interfaces: ["eth0"]
             } = mmds_config
    end

    test "enforces required keys for mmds config" do
      assert_raise NimbleOptions.ValidationError,
                   ~r/required :network_interfaces option not found/,
                   fn ->
                     Firecracker.new()
                     |> Firecracker.configure(:mmds_config, version: "V2")
                   end
    end

    test "enforces types for mmds config" do
      assert_raise NimbleOptions.ValidationError, ~r/invalid value for :network_interfaces/, fn ->
        Firecracker.new()
        |> Firecracker.configure(:mmds_config, network_interfaces: "not a list")
      end

      assert_raise NimbleOptions.ValidationError, ~r/invalid value for :version/, fn ->
        Firecracker.new()
        |> Firecracker.configure(:mmds_config, network_interfaces: ["eth0"], version: 123)
      end

      assert_raise NimbleOptions.ValidationError, ~r/invalid value for :ipv4_address/, fn ->
        Firecracker.new()
        |> Firecracker.configure(:mmds_config, network_interfaces: ["eth0"], ipv4_address: 123)
      end
    end

    test "configures metrics" do
      vm =
        Firecracker.new()
        |> Firecracker.configure(:metrics, metrics_path: "/tmp/firecracker_metrics.fifo")

      assert %Firecracker{metrics: %Firecracker.Metrics{} = metrics} = vm
      assert %Firecracker.Metrics{metrics_path: "/tmp/firecracker_metrics.fifo"} = metrics
    end

    test "enforces required keys for metrics" do
      assert_raise NimbleOptions.ValidationError,
                   ~r/required :metrics_path option not found/,
                   fn ->
                     Firecracker.new()
                     |> Firecracker.configure(:metrics, [])
                   end
    end

    test "enforces types for metrics" do
      assert_raise NimbleOptions.ValidationError, ~r/invalid value for :metrics_path/, fn ->
        Firecracker.new()
        |> Firecracker.configure(:metrics, metrics_path: 123)
      end
    end

    test "configures the vsock device" do
      vm =
        Firecracker.new()
        |> Firecracker.configure(:vsock, guest_cid: 3, uds_path: "/tmp/firecracker.vsock")

      assert %Firecracker{vsock: %Firecracker.Vsock{} = vsock_config} = vm
      assert %Firecracker.Vsock{guest_cid: 3, uds_path: "/tmp/firecracker.vsock"} = vsock_config
    end

    test "enforces required keys for vsock" do
      assert_raise NimbleOptions.ValidationError, ~r/required :guest_cid option not found/, fn ->
        Firecracker.new()
        |> Firecracker.configure(:vsock, uds_path: "/tmp/vsock.sock")
      end

      assert_raise NimbleOptions.ValidationError, ~r/required :uds_path option not found/, fn ->
        Firecracker.new()
        |> Firecracker.configure(:vsock, guest_cid: 3)
      end
    end

    test "enforces types for vsock" do
      assert_raise NimbleOptions.ValidationError, ~r/invalid value for :guest_cid/, fn ->
        Firecracker.new()
        |> Firecracker.configure(:vsock, guest_cid: "not an integer", uds_path: "/tmp/vsock.sock")
      end

      assert_raise NimbleOptions.ValidationError, ~r/invalid value for :uds_path/, fn ->
        Firecracker.new()
        |> Firecracker.configure(:vsock, guest_cid: 3, uds_path: 123)
      end
    end

    test "configures the entropy device" do
      rate_limiter =
        Firecracker.RateLimiter.new()
        |> Firecracker.RateLimiter.ops(
          size: 10_000,
          refill_time: 60,
          one_time_burst: 5_000
        )

      vm =
        Firecracker.new()
        |> Firecracker.configure(:entropy, rate_limiter: rate_limiter)

      assert %Firecracker{entropy: %Firecracker.Entropy{} = entropy} = vm

      assert %Firecracker.Entropy{
               rate_limiter: %Firecracker.RateLimiter{
                 bandwidth: nil,
                 ops: %Firecracker.RateLimiter.TokenBucket{
                   one_time_burst: 5000,
                   refill_time: 60,
                   size: 10000
                 }
               }
             } = entropy
    end

    test "configures the serial device" do
      vm =
        Firecracker.new()
        |> Firecracker.configure(:serial, output_path: "/tmp/serial.log")

      assert %Firecracker{serial: %Firecracker.Serial{} = serial} = vm
      assert %Firecracker.Serial{output_path: "/tmp/serial.log"} = serial
    end

    test "raises on invalid key" do
      assert_raise ArgumentError, ~r/invalid configuration key: :invalid_key/, fn ->
        Firecracker.new()
        |> Firecracker.configure(:invalid_key, some_value: "test")
      end
    end
  end

  describe "configure/3 post-boot data only changes" do
    setup do
      vm =
        Firecracker.new()
        |> Map.put(:state, :running)

      [vm: vm]
    end

    test "allows modifying balloon amount_mib post-boot", %{vm: vm} do
      vm = Firecracker.configure(vm, :balloon, amount_mib: 200)
      assert %Firecracker.Balloon{amount_mib: 200} = vm.balloon
    end

    test "allows modifying balloon stats_polling_interval_s post-boot", %{vm: vm} do
      vm = Firecracker.configure(vm, :balloon, stats_polling_interval_s: 10)
      assert %Firecracker.Balloon{stats_polling_interval_s: 10} = vm.balloon
    end

    test "raises when trying to modify balloon deflate_on_oom post-boot", %{vm: vm} do
      assert_raise NimbleOptions.ValidationError, ~r/unknown options/, fn ->
        Firecracker.configure(vm, :balloon, deflate_on_oom: false)
      end
    end

    test "enforces types for balloon post-boot modifications", %{vm: vm} do
      assert_raise NimbleOptions.ValidationError, ~r/invalid value for :amount_mib/, fn ->
        Firecracker.configure(vm, :balloon, amount_mib: "not an integer")
      end

      assert_raise NimbleOptions.ValidationError,
                   ~r/invalid value for :stats_polling_interval_s/,
                   fn ->
                     Firecracker.configure(vm, :balloon,
                       stats_polling_interval_s: "not an integer"
                     )
                   end
    end

    test "allows modifying all machine_config fields post-boot", %{vm: vm} do
      vm =
        Firecracker.configure(vm, :machine_config,
          vcpu_count: 4,
          mem_size_mib: 1024,
          smt: true,
          track_dirty_pages: true
        )

      assert %Firecracker.MachineConfig{
               vcpu_count: 4,
               mem_size_mib: 1024,
               smt: true,
               track_dirty_pages: true
             } = vm.machine_config
    end

    test "enforces types for machine_config post-boot modifications", %{vm: vm} do
      assert_raise NimbleOptions.ValidationError, ~r/invalid value for :vcpu_count/, fn ->
        Firecracker.configure(vm, :machine_config, vcpu_count: "not an integer")
      end

      assert_raise NimbleOptions.ValidationError, ~r/invalid value for :mem_size_mib/, fn ->
        Firecracker.configure(vm, :machine_config, mem_size_mib: "not an integer")
      end
    end

    test "raises when trying to modify boot_source post-boot", %{vm: vm} do
      assert_raise NimbleOptions.ValidationError, ~r/unknown options.*kernel_image_path/, fn ->
        Firecracker.configure(vm, :boot_source, kernel_image_path: "/new/kernel")
      end

      assert_raise NimbleOptions.ValidationError, ~r/unknown options.*boot_args/, fn ->
        Firecracker.configure(vm, :boot_source, boot_args: "new args")
      end

      assert_raise NimbleOptions.ValidationError, ~r/unknown options.*initrd_path/, fn ->
        Firecracker.configure(vm, :boot_source, initrd_path: "/new/initrd")
      end
    end

    test "raises when trying to modify cpu_config post-boot", %{vm: vm} do
      assert_raise NimbleOptions.ValidationError, ~r/unknown options/, fn ->
        Firecracker.configure(vm, :cpu_config, kvm_capabilities: ["!56"])
      end
    end

    test "raises when trying to modify entropy post-boot", %{vm: vm} do
      rate_limiter = Firecracker.RateLimiter.new()

      assert_raise NimbleOptions.ValidationError, ~r/unknown options.*rate_limiter/, fn ->
        Firecracker.configure(vm, :entropy, rate_limiter: rate_limiter)
      end
    end

    test "raises when trying to modify logger post-boot", %{vm: vm} do
      assert_raise NimbleOptions.ValidationError, ~r/unknown options.*level/, fn ->
        Firecracker.configure(vm, :logger, level: "Debug")
      end

      assert_raise NimbleOptions.ValidationError, ~r/unknown options.*log_path/, fn ->
        Firecracker.configure(vm, :logger, log_path: "/tmp/new.log")
      end
    end

    test "raises when trying to modify metrics post-boot", %{vm: vm} do
      assert_raise NimbleOptions.ValidationError, ~r/unknown options.*metrics_path/, fn ->
        Firecracker.configure(vm, :metrics, metrics_path: "/tmp/new_metrics.fifo")
      end
    end

    test "raises when trying to modify mmds_config post-boot", %{vm: vm} do
      assert_raise NimbleOptions.ValidationError, ~r/unknown options.*network_interfaces/, fn ->
        Firecracker.configure(vm, :mmds_config, network_interfaces: ["eth0"])
      end

      assert_raise NimbleOptions.ValidationError, ~r/unknown options.*version/, fn ->
        Firecracker.configure(vm, :mmds_config, version: "V2")
      end
    end

    test "raises when trying to modify serial post-boot", %{vm: vm} do
      assert_raise NimbleOptions.ValidationError, ~r/unknown options.*output_path/, fn ->
        Firecracker.configure(vm, :serial, output_path: "/tmp/new_serial.log")
      end
    end

    test "raises when trying to modify vsock post-boot", %{vm: vm} do
      assert_raise NimbleOptions.ValidationError, ~r/unknown options.*guest_cid/, fn ->
        Firecracker.configure(vm, :vsock, guest_cid: 5)
      end

      assert_raise NimbleOptions.ValidationError, ~r/unknown options.*uds_path/, fn ->
        Firecracker.configure(vm, :vsock, uds_path: "/tmp/new.sock")
      end
    end
  end

  describe "configure/3 exited data only changes" do
    test "raises trying to configure anything in exited state" do
      assert_raise ArgumentError, ~r/cannot modify configuration/, fn ->
        vm = Firecracker.new()
        vm = %{vm | state: :exited}

        Firecracker.configure(vm, :boot_source, kernel_image_path: "./vmlinux")
      end
    end
  end

  describe "add/4 pre-boot data only changes" do
    test "adds a network interface" do
      vm =
        Firecracker.new()
        |> Firecracker.add(:network_interface, "eth0", host_dev_name: "tap0")

      assert %Firecracker{
               network_interfaces: %{"eth0" => %Firecracker.NetworkInterface{} = iface}
             } = vm

      assert %Firecracker.NetworkInterface{iface_id: "eth0", host_dev_name: "tap0"} = iface
    end

    test "adds a drive" do
      vm =
        Firecracker.new()
        |> Firecracker.add(:drive, "rootfs",
          path_on_host: "/path/to/rootfs.ext4",
          is_root_device: true
        )

      assert %Firecracker{drives: %{"rootfs" => %Firecracker.Drive{} = drive}} = vm

      assert %Firecracker.Drive{
               drive_id: "rootfs",
               path_on_host: "/path/to/rootfs.ext4",
               is_root_device: true
             } = drive
    end

    test "supports adding multiple drives" do
      vm =
        Firecracker.new()
        |> Firecracker.add(:drive, "rootfs",
          path_on_host: "/path/to/rootfs.ext4",
          is_root_device: true
        )
        |> Firecracker.add(:drive, "data",
          path_on_host: "/path/to/data.ext4",
          is_root_device: false
        )

      assert %Firecracker{drives: drives} = vm
      assert map_size(drives) == 2

      %{"data" => data_drive, "rootfs" => root_drive} = drives

      assert %Firecracker.Drive{drive_id: "data", is_root_device: false} = data_drive
      assert %Firecracker.Drive{drive_id: "rootfs", is_root_device: true} = root_drive
    end

    test "supports adding multiple network interfaces" do
      vm =
        Firecracker.new()
        |> Firecracker.add(:network_interface, "eth0", host_dev_name: "tap0")
        |> Firecracker.add(:network_interface, "eth1", host_dev_name: "tap1")

      assert %Firecracker{network_interfaces: interfaces} = vm
      assert map_size(interfaces) == 2

      %{"eth1" => eth1, "eth0" => eth0} = interfaces

      assert %Firecracker.NetworkInterface{iface_id: "eth1", host_dev_name: "tap1"} = eth1
      assert %Firecracker.NetworkInterface{iface_id: "eth0", host_dev_name: "tap0"} = eth0
    end

    test "adds a pmem device" do
      vm =
        Firecracker.new()
        |> Firecracker.add(:pmem, "pmem0",
          path_on_host: "/path/to/pmem.img",
          root_device: false
        )

      assert %Firecracker{pmems: %{"pmem0" => %Firecracker.Pmem{} = pmem}} = vm

      assert %Firecracker.Pmem{
               id: "pmem0",
               path_on_host: "/path/to/pmem.img",
               root_device: false
             } = pmem
    end

    test "supports adding multiple pmem devices" do
      vm =
        Firecracker.new()
        |> Firecracker.add(:pmem, "pmem0",
          path_on_host: "/path/to/pmem0.img",
          root_device: true,
          read_only: false
        )
        |> Firecracker.add(:pmem, "pmem1",
          path_on_host: "/path/to/pmem1.img",
          read_only: true
        )

      assert %Firecracker{pmems: pmems} = vm
      assert map_size(pmems) == 2

      %{"pmem0" => pmem0, "pmem1" => pmem1} = pmems

      assert %Firecracker.Pmem{id: "pmem0", root_device: true, read_only: false} = pmem0
      assert %Firecracker.Pmem{id: "pmem1", read_only: true} = pmem1
    end

    test "raises on invalid key" do
      assert_raise ArgumentError, ~r/invalid configuration key: :invalid_key/, fn ->
        Firecracker.new()
        |> Firecracker.add(:invalid_key, "foo", %{some_field: "value"})
      end
    end

    test "enforces required keys for drive" do
      assert_raise NimbleOptions.ValidationError,
                   ~r/required :is_root_device option not found/,
                   fn ->
                     Firecracker.new()
                     |> Firecracker.add(:drive, "rootfs", path_on_host: "/path/to/rootfs")
                   end
    end

    test "enforces types for drive" do
      assert_raise NimbleOptions.ValidationError, ~r/invalid value for :drive_id/, fn ->
        Firecracker.new()
        |> Firecracker.add(:drive, 123, is_root_device: true, path_on_host: "/path/to/rootfs")
      end

      assert_raise NimbleOptions.ValidationError, ~r/invalid value for :is_root_device/, fn ->
        Firecracker.new()
        |> Firecracker.add(:drive, "rootfs",
          is_root_device: "not a boolean",
          path_on_host: "/path/to/rootfs"
        )
      end

      assert_raise NimbleOptions.ValidationError, ~r/invalid value for :path_on_host/, fn ->
        Firecracker.new()
        |> Firecracker.add(:drive, "rootfs", is_root_device: true, path_on_host: 123)
      end

      assert_raise NimbleOptions.ValidationError, ~r/invalid value for :is_read_only/, fn ->
        Firecracker.new()
        |> Firecracker.add(:drive, "rootfs",
          is_root_device: true,
          path_on_host: "/path/to/rootfs",
          is_read_only: "not a boolean"
        )
      end
    end

    test "enforces required keys for network interface" do
      assert_raise NimbleOptions.ValidationError,
                   ~r/required :host_dev_name option not found/,
                   fn ->
                     Firecracker.new()
                     |> Firecracker.add(:network_interface, "eth0",
                       guest_mac: "AA:FC:00:00:00:01"
                     )
                   end
    end

    test "enforces types for network interface" do
      assert_raise NimbleOptions.ValidationError, ~r/invalid value for :iface_id/, fn ->
        Firecracker.new()
        |> Firecracker.add(:network_interface, 123, host_dev_name: "tap0")
      end

      assert_raise NimbleOptions.ValidationError, ~r/invalid value for :host_dev_name/, fn ->
        Firecracker.new()
        |> Firecracker.add(:network_interface, "eth0", host_dev_name: 123)
      end

      assert_raise NimbleOptions.ValidationError, ~r/invalid value for :guest_mac/, fn ->
        Firecracker.new()
        |> Firecracker.add(:network_interface, "eth0", host_dev_name: "tap0", guest_mac: 123)
      end
    end

    test "enforces required keys for pmem" do
      assert_raise NimbleOptions.ValidationError,
                   ~r/required :path_on_host option not found/,
                   fn ->
                     Firecracker.new()
                     |> Firecracker.add(:pmem, "pmem0", root_device: false)
                   end
    end

    test "enforces types for pmem" do
      assert_raise NimbleOptions.ValidationError, ~r/invalid value for :id/, fn ->
        Firecracker.new()
        |> Firecracker.add(:pmem, 123, path_on_host: "/path/to/pmem.img")
      end

      assert_raise NimbleOptions.ValidationError, ~r/invalid value for :path_on_host/, fn ->
        Firecracker.new()
        |> Firecracker.add(:pmem, "pmem0", path_on_host: 123)
      end

      assert_raise NimbleOptions.ValidationError, ~r/invalid value for :root_device/, fn ->
        Firecracker.new()
        |> Firecracker.add(:pmem, "pmem0",
          path_on_host: "/path/to/pmem.img",
          root_device: "not a boolean"
        )
      end

      assert_raise NimbleOptions.ValidationError, ~r/invalid value for :read_only/, fn ->
        Firecracker.new()
        |> Firecracker.add(:pmem, "pmem0",
          path_on_host: "/path/to/pmem.img",
          read_only: "not a boolean"
        )
      end
    end
  end

  describe "add/4 post-boot data only changes" do
    setup do
      vm =
        Firecracker.new()
        |> Firecracker.configure(:boot_source, kernel_image_path: "/path/to/kernel")
        |> Firecracker.add(:drive, "rootfs",
          path_on_host: "/path/to/rootfs",
          is_root_device: true,
          is_read_only: false
        )
        |> Map.put(:state, :running)

      [vm: vm]
    end

    test "allows updating drive path_on_host post-boot", %{vm: vm} do
      vm = Firecracker.add(vm, :drive, "rootfs", path_on_host: "/new/path/to/rootfs")

      assert %Firecracker.Drive{
               drive_id: "rootfs",
               path_on_host: "/new/path/to/rootfs"
             } = vm.drives["rootfs"]
    end

    test "allows updating drive drive_id post-boot", %{vm: vm} do
      vm = Firecracker.add(vm, :drive, "rootfs", drive_id: "rootfs")

      assert %Firecracker.Drive{drive_id: "rootfs"} = vm.drives["rootfs"]
    end

    test "enforces types for drive post-boot updates", %{vm: vm} do
      assert_raise NimbleOptions.ValidationError, ~r/invalid value for :path_on_host/, fn ->
        Firecracker.add(vm, :drive, "rootfs", path_on_host: 123)
      end
    end

    test "raises when adding drive with non-updatable is_root_device field", %{vm: vm} do
      assert_raise NimbleOptions.ValidationError, ~r/unknown options.*is_root_device/, fn ->
        Firecracker.add(vm, :drive, "rootfs", is_root_device: false)
      end
    end

    test "raises when adding drive with non-updatable is_read_only field", %{vm: vm} do
      assert_raise NimbleOptions.ValidationError, ~r/unknown options.*is_read_only/, fn ->
        Firecracker.add(vm, :drive, "rootfs", is_read_only: true)
      end
    end

    test "raises when adding drive with non-updatable cache_type field", %{vm: vm} do
      assert_raise NimbleOptions.ValidationError, ~r/unknown options.*cache_type/, fn ->
        Firecracker.add(vm, :drive, "rootfs", cache_type: "unsafe")
      end
    end

    test "raises when trying to add new drive post-boot", %{vm: vm} do
      assert_raise NimbleOptions.ValidationError, ~r/unknown options.*is_root_device/, fn ->
        Firecracker.add(vm, :drive, "newdrive",
          path_on_host: "/path/to/newdrive",
          is_root_device: false
        )
      end
    end

    test "raises when adding network_interface with non-updatable host_dev_name field", %{
      vm: vm
    } do
      assert_raise NimbleOptions.ValidationError, ~r/unknown options.*host_dev_name/, fn ->
        Firecracker.add(vm, :network_interface, "eth0", host_dev_name: "tap0")
      end
    end

    test "raises when adding network_interface with non-updatable guest_mac field", %{vm: vm} do
      assert_raise NimbleOptions.ValidationError, ~r/unknown options.*guest_mac/, fn ->
        Firecracker.add(vm, :network_interface, "eth0", guest_mac: "AA:FC:00:00:00:01")
      end
    end

    test "raises when trying to add new network_interface post-boot", %{vm: vm} do
      assert_raise NimbleOptions.ValidationError, ~r/unknown options.*host_dev_name/, fn ->
        Firecracker.add(vm, :network_interface, "eth0", host_dev_name: "tap0")
      end
    end

    test "raises when trying to add pmem post-boot", %{vm: vm} do
      # Pmem has no updatable fields, so any modification should raise
      assert_raise NimbleOptions.ValidationError, ~r/unknown options.*path_on_host/, fn ->
        Firecracker.add(vm, :pmem, "pmem0",
          path_on_host: "/path/to/pmem",
          root_device: false
        )
      end
    end
  end

  describe "add/4 exited data only changes" do
    test "raises when adding any device in exited state" do
      vm =
        Firecracker.new()
        |> Firecracker.configure(:boot_source, kernel_image_path: "/path/to/kernel")
        |> Firecracker.add(:drive, "rootfs",
          path_on_host: "/path/to/rootfs",
          is_root_device: true,
          is_read_only: false
        )
        |> Map.put(:state, :exited)

      assert_raise ArgumentError, ~r/cannot modify.*when VM is in state :exited/, fn ->
        Firecracker.add(vm, :drive, "newdrive",
          path_on_host: "/path/to/newdrive",
          is_root_device: false
        )
      end

      assert_raise ArgumentError, ~r/cannot modify.*when VM is in state :exited/, fn ->
        Firecracker.add(vm, :network_interface, "eth0", host_dev_name: "tap0")
      end

      assert_raise ArgumentError, ~r/cannot modify.*when VM is in state :exited/, fn ->
        Firecracker.add(vm, :pmem, "pmem0", path_on_host: "/path/to/pmem")
      end
    end
  end

  describe "jail/2" do
    test "configures a VM with a jailer" do
      vm =
        Firecracker.new()
        |> Firecracker.jail(uid: 1000, gid: 1000)

      assert %Firecracker{jailer: %Firecracker.Jailer{uid: 1000, gid: 1000}} = vm
    end

    test "raises an error if VM is not in initial state" do
      vm = %Firecracker{state: :started}

      assert_raise ArgumentError, "cannot apply jailer when VM is in state :started", fn ->
        Firecracker.jail(vm, uid: 1000, gid: 1000)
      end
    end

    test "configures all jailer options" do
      vm =
        Firecracker.new()
        |> Firecracker.jail(
          uid: 1000,
          gid: 1000,
          parent_cgroup: "fc",
          chroot_base_dir: "/var/srv/jailer",
          netns: "/var/run/netns/my-netns"
        )

      assert %Firecracker{
               jailer: %Firecracker.Jailer{
                 uid: 1000,
                 gid: 1000,
                 parent_cgroup: "fc",
                 chroot_base_dir: "/var/srv/jailer",
                 netns: "/var/run/netns/my-netns"
               }
             } = vm
    end

    test "enforces required keys" do
      assert_raise NimbleOptions.ValidationError, ~r/required :uid option not found/, fn ->
        Firecracker.new()
        |> Firecracker.jail(gid: 1000)
      end

      assert_raise NimbleOptions.ValidationError, ~r/required :gid option not found/, fn ->
        Firecracker.new()
        |> Firecracker.jail(uid: 1000)
      end
    end

    test "enforces types for uid and gid" do
      assert_raise NimbleOptions.ValidationError, ~r/invalid value for :uid/, fn ->
        Firecracker.new()
        |> Firecracker.jail(uid: "not an integer", gid: 1000)
      end

      assert_raise NimbleOptions.ValidationError, ~r/invalid value for :gid/, fn ->
        Firecracker.new()
        |> Firecracker.jail(uid: 1000, gid: "not an integer")
      end

      assert_raise NimbleOptions.ValidationError, ~r/invalid value for :uid/, fn ->
        Firecracker.new()
        |> Firecracker.jail(uid: -1, gid: 1000)
      end
    end

    test "enforces types for optional string fields" do
      assert_raise NimbleOptions.ValidationError, ~r/invalid value for :parent_cgroup/, fn ->
        Firecracker.new()
        |> Firecracker.jail(uid: 1000, gid: 1000, parent_cgroup: 123)
      end

      assert_raise NimbleOptions.ValidationError, ~r/invalid value for :netns/, fn ->
        Firecracker.new()
        |> Firecracker.jail(uid: 1000, gid: 1000, netns: 123)
      end

      assert_raise NimbleOptions.ValidationError, ~r/invalid value for :jailer_path/, fn ->
        Firecracker.new()
        |> Firecracker.jail(uid: 1000, gid: 1000, jailer_path: 123)
      end

      assert_raise NimbleOptions.ValidationError, ~r/invalid value for :cgroup_version/, fn ->
        Firecracker.new()
        |> Firecracker.jail(uid: 1000, gid: 1000, cgroup_version: 123)
      end

      assert_raise NimbleOptions.ValidationError, ~r/invalid value for :chroot_base_dir/, fn ->
        Firecracker.new()
        |> Firecracker.jail(uid: 1000, gid: 1000, chroot_base_dir: 123)
      end
    end

    test "enforces types for boolean fields" do
      assert_raise NimbleOptions.ValidationError, ~r/invalid value for :daemonize/, fn ->
        Firecracker.new()
        |> Firecracker.jail(uid: 1000, gid: 1000, daemonize: "not a boolean")
      end

      assert_raise NimbleOptions.ValidationError, ~r/invalid value for :new_pid_ns/, fn ->
        Firecracker.new()
        |> Firecracker.jail(uid: 1000, gid: 1000, new_pid_ns: "not a boolean")
      end
    end

    test "enforces types for keyword_list fields" do
      assert_raise NimbleOptions.ValidationError, ~r/invalid value for :cgroups/, fn ->
        Firecracker.new()
        |> Firecracker.jail(uid: 1000, gid: 1000, cgroups: "not a keyword list")
      end

      assert_raise NimbleOptions.ValidationError, ~r/invalid value for :resource_limits/, fn ->
        Firecracker.new()
        |> Firecracker.jail(uid: 1000, gid: 1000, resource_limits: "not a keyword list")
      end
    end

    test "rejects unknown options" do
      assert_raise NimbleOptions.ValidationError, ~r/unknown options.*invalid_option/, fn ->
        Firecracker.new()
        |> Firecracker.jail(uid: 1000, gid: 1000, invalid_option: "value")
      end
    end

    test "allows all valid options" do
      vm =
        Firecracker.new()
        |> Firecracker.jail(
          uid: 1000,
          gid: 1000,
          parent_cgroup: "fc",
          cgroups: [cpu: "1"],
          netns: "/var/run/netns/my-netns",
          resource_limits: [no_file: 1024],
          daemonize: true,
          new_pid_ns: true,
          jailer_path: "/usr/bin/jailer",
          cgroup_version: "2",
          chroot_base_dir: "/var/srv/jailer"
        )

      assert %Firecracker{
               jailer: %Firecracker.Jailer{
                 uid: 1000,
                 gid: 1000,
                 parent_cgroup: "fc",
                 cgroups: [cpu: "1"],
                 netns: "/var/run/netns/my-netns",
                 resource_limits: [no_file: 1024],
                 daemonize: true,
                 new_pid_ns: true,
                 jailer_path: "/usr/bin/jailer",
                 cgroup_version: "2",
                 chroot_base_dir: "/var/srv/jailer"
               }
             } = vm
    end
  end

  describe "cgroup/3" do
    setup do
      vm =
        Firecracker.new()
        |> Firecracker.jail(uid: 1000, gid: 1000)

      {:ok, vm: vm}
    end

    test "adds a cgroup configuration to a VM with a jailer", %{vm: vm} do
      updated_vm = Firecracker.cgroup(vm, "cpu.weight", 10)

      assert %Firecracker{
               jailer: %Firecracker.Jailer{
                 uid: 1000,
                 gid: 1000,
                 cgroups: %{"cpu.weight" => 10}
               }
             } = updated_vm
    end

    test "adds multiple cgroup configurations", %{vm: vm} do
      updated_vm =
        vm
        |> Firecracker.cgroup("cpu.weight", 10)
        |> Firecracker.cgroup("memory.high", "512M")

      assert %Firecracker{
               jailer: %Firecracker.Jailer{
                 cgroups: %{"cpu.weight" => 10, "memory.high" => "512M"}
               }
             } = updated_vm
    end

    test "overrides existing cgroup configuration", %{vm: vm} do
      updated_vm =
        vm
        |> Firecracker.cgroup("cpu.weight", 10)
        |> Firecracker.cgroup("cpu.weight", 20)

      assert %Firecracker{
               jailer: %Firecracker.Jailer{
                 cgroups: %{"cpu.weight" => 20}
               }
             } = updated_vm
    end

    test "raises error if VM is not in initial state" do
      vm =
        Firecracker.new()
        |> Firecracker.jail(uid: 1000, gid: 1000)
        |> Map.put(:state, :started)

      assert_raise ArgumentError, ~r/cannot apply cgroup/, fn ->
        Firecracker.cgroup(vm, "cpu.weight", 10)
      end
    end

    test "raises error if VM has no jailer configured" do
      vm = Firecracker.new()

      assert_raise ArgumentError, "unable to configure cgroup on VM with no jailer present", fn ->
        Firecracker.cgroup(vm, "cpu.weight", 10)
      end
    end
  end

  describe "resource_limit/3" do
    setup do
      vm =
        Firecracker.new()
        |> Firecracker.jail(uid: 1000, gid: 1000)

      {:ok, vm: vm}
    end

    test "adds a resource limit to a VM with a jailer", %{vm: vm} do
      updated_vm = Firecracker.resource_limit(vm, "RLIMIT_NOFILE", 1024)

      assert %Firecracker{
               jailer: %Firecracker.Jailer{
                 uid: 1000,
                 gid: 1000,
                 resource_limits: %{"RLIMIT_NOFILE" => 1024}
               }
             } = updated_vm
    end

    test "adds multiple resource limits", %{vm: vm} do
      updated_vm =
        vm
        |> Firecracker.resource_limit("RLIMIT_NOFILE", 1024)
        |> Firecracker.resource_limit("RLIMIT_FSIZE", "unlimited")

      assert %Firecracker{
               jailer: %Firecracker.Jailer{
                 resource_limits: %{"RLIMIT_NOFILE" => 1024, "RLIMIT_FSIZE" => "unlimited"}
               }
             } = updated_vm
    end

    test "overrides existing resource limit", %{vm: vm} do
      updated_vm =
        vm
        |> Firecracker.resource_limit("RLIMIT_NOFILE", 1024)
        |> Firecracker.resource_limit("RLIMIT_NOFILE", 2048)

      assert %Firecracker{
               jailer: %Firecracker.Jailer{
                 resource_limits: %{"RLIMIT_NOFILE" => 2048}
               }
             } = updated_vm
    end

    test "raises error if VM is not in initial state" do
      vm =
        Firecracker.new()
        |> Firecracker.jail(uid: 1000, gid: 1000)
        |> Map.put(:state, :started)

      assert_raise ArgumentError,
                   "cannot apply resource limit when VM is in state :started",
                   fn ->
                     Firecracker.resource_limit(vm, "RLIMIT_NOFILE", 1024)
                   end
    end

    test "raises error if VM has no jailer configured" do
      vm = Firecracker.new()

      assert_raise ArgumentError, ~r/unable to configure resource limit/, fn ->
        Firecracker.resource_limit(vm, "RLIMIT_NOFILE", 1024)
      end
    end
  end

  describe "which/1" do
    test "returns the :firecracker_path if one is set in the struct" do
      vm =
        Firecracker.new()
        |> Firecracker.set_option(:firecracker_path, "/home/ubuntu/bin/firecracker")

      assert Firecracker.which(vm) == "/home/ubuntu/bin/firecracker"
    end

    test "uses the environment :firecracker_path if none is set in struct" do
      original_env = Application.get_env(:firecracker, Firecracker, [])

      try do
        Application.put_env(:firecracker, Firecracker, firecracker_path: "/usr/bin/firecracker")
        vm = Firecracker.new()

        assert Firecracker.which(vm) == "/usr/bin/firecracker"
      after
        Application.put_env(:firecracker, Firecracker, original_env)
      end
    end

    test "uses a default path if no environment is set" do
      vm = Firecracker.new()

      assert Firecracker.which(vm) =~ ".firecracker/bin/firecracker"
    end

    test "prefers struct path over environment path" do
      original_env = Application.get_env(:firecracker, Firecracker, [])

      try do
        Application.put_env(:firecracker, Firecracker, firecracker_path: "/usr/bin/firecracker")

        vm =
          Firecracker.new()
          |> Firecracker.set_option(:firecracker_path, "/home/ubuntu/bin/firecracker")

        assert Firecracker.which(vm) == "/home/ubuntu/bin/firecracker"
      after
        Application.put_env(:firecracker, Firecracker, original_env)
      end
    end
  end

  describe "which/0" do
    test "uses the environment :firecracker_path" do
      original_env = Application.get_env(:firecracker, Firecracker, [])

      try do
        Application.put_env(:firecracker, Firecracker, firecracker_path: "/usr/bin/firecracker")

        assert Firecracker.which() == "/usr/bin/firecracker"
      after
        Application.put_env(:firecracker, Firecracker, original_env)
      end
    end

    test "uses the default path if no environment is set" do
      assert Firecracker.which() =~ ".firecracker/bin/firecracker"
    end
  end

  describe "dry_run/1" do
    test "returns the default firecracker path" do
      vm = Firecracker.new()

      assert %{binary: path} = Firecracker.dry_run(vm)

      assert path =~ ".firecracker/bin/firecracker"
    end

    test "returns a given :firecracker_path" do
      vm =
        Firecracker.new()
        |> Firecracker.set_option(:firecracker_path, "/usr/local/bin/firecracker")

      assert %{binary: "/usr/local/bin/firecracker"} = Firecracker.dry_run(vm)
    end

    test "returns the default api socket" do
      %Firecracker{api_sock: sock} = vm = Firecracker.new()

      assert %{args: ["--api-sock", ^sock | _]} =
               Firecracker.dry_run(vm)
    end

    test "returns the default id" do
      %Firecracker{id: id, api_sock: sock} = vm = Firecracker.new()

      assert %{args: args} = Firecracker.dry_run(vm)
      assert ["--api-sock", ^sock, "--id", ^id] = args
    end

    @boolean_flags [:boot_timer, :no_api, :no_seccomp, :show_level, :show_log_origin]
    for flag <- @boolean_flags do
      test "returns flag #{flag} when set" do
        expected_key =
          unquote(flag)
          |> Atom.to_string()
          |> String.split("_")
          |> Enum.join("-")

        vm =
          Firecracker.new()
          |> Firecracker.set_option(unquote(flag), true)

        assert %{args: args} = Firecracker.dry_run(vm)
        assert "--#{expected_key}" in args
      end

      test "ignores #{flag} if it is set to false" do
        expected_key =
          unquote(flag)
          |> Atom.to_string()
          |> String.split("_")
          |> Enum.join("-")

        vm =
          Firecracker.new()
          |> Firecracker.set_option(unquote(flag), false)

        assert %{args: args} = Firecracker.dry_run(vm)
        refute "--#{expected_key}" in args
      end
    end

    @value_flags [
      {:config_file, "config.json"},
      {:http_api_max_payload_size, 51200},
      {:level, "Info"},
      {:log_path, "log.txt"},
      {:metrics_path, "metrics.txt"},
      {:mmds_size_limit, 100},
      {:module, "foo"},
      {:parent_cpu_time_us, 100},
      {:seccomp_filter, "foo"},
      {:start_time_cpu_us, 100},
      {:start_time_us, 100}
    ]
    for {flag, value} <- @value_flags do
      test "returns flag #{flag} when set" do
        expected_key =
          unquote(flag)
          |> Atom.to_string()
          |> String.split("_")
          |> Enum.join("-")

        vm =
          Firecracker.new()
          |> Firecracker.set_option(unquote(flag), unquote(value))

        assert %{args: args} = Firecracker.dry_run(vm)
        assert "--#{expected_key}" in args
        assert "#{unquote(value)}" in args
      end
    end

    test "returns multiple options when set" do
      vm =
        Firecracker.new()
        |> Firecracker.set_option(:api_sock, "/tmp/fire.sock")
        |> Firecracker.set_option(:no_api, true)
        |> Firecracker.set_option(:log_path, "log.txt")

      assert %{args: args} = Firecracker.dry_run(vm)

      assert [
               "--id",
               "anonymous-instance" <> _,
               "--log-path",
               "log.txt",
               "--no-api"
             ] = args
    end

    test "returns configuration for a balloon device" do
      vm =
        Firecracker.new()
        |> Firecracker.configure(:balloon, amount_mib: 100, deflate_on_oom: true)

      %{config: config} = Firecracker.dry_run(vm)
      assert %{"balloon" => %{"amount_mib" => 100, "deflate_on_oom" => true}} = config
    end

    test "returns configuration for a boot source" do
      vm =
        Firecracker.new()
        |> Firecracker.configure(:boot_source,
          kernel_image_path: "/path/to/kernel",
          boot_args: "console=ttyS0"
        )

      %{config: config} = Firecracker.dry_run(vm)

      assert %{
               "boot-source" => %{
                 "kernel_image_path" => "/path/to/kernel",
                 "boot_args" => "console=ttyS0"
               }
             } = config
    end

    test "returns configuration for a cpu config" do
      vm =
        Firecracker.new()
        |> Firecracker.configure(:cpu_config, kvm_capabilities: ["!56"])

      %{config: config} = Firecracker.dry_run(vm)
      assert %{"cpu-config" => %{"kvm_capabilities" => ["!56"]}} = config
    end

    test "returns configuration for logger" do
      vm =
        Firecracker.new()
        |> Firecracker.configure(:logger,
          log_path: "/tmp/fc.log",
          level: "Info",
          show_level: true
        )

      %{config: config} = Firecracker.dry_run(vm)

      assert %{
               "logger" => %{
                 "log_path" => "/tmp/fc.log",
                 "level" => "Info",
                 "show_level" => true
               }
             } = config
    end

    test "returns configuration for a machine config" do
      vm =
        Firecracker.new()
        |> Firecracker.configure(:machine_config, vcpu_count: 4, mem_size_mib: 1024)

      %{config: config} = Firecracker.dry_run(vm)
      assert %{"machine-config" => %{"vcpu_count" => 4, "mem_size_mib" => 1024}} = config
    end

    test "returns configuration for an mmds config" do
      vm =
        Firecracker.new()
        |> Firecracker.configure(:mmds_config, network_interfaces: ["eth0"], version: "V2")

      %{config: config} = Firecracker.dry_run(vm)
      assert %{"mmds-config" => %{"network_interfaces" => ["eth0"], "version" => "V2"}} = config
    end

    test "returns configuration for metrics" do
      vm =
        Firecracker.new()
        |> Firecracker.configure(:metrics, metrics_path: "/tmp/metrics.fifo")

      %{config: config} = Firecracker.dry_run(vm)
      assert %{"metrics" => %{"metrics_path" => "/tmp/metrics.fifo"}} = config
    end

    test "returns configuration for a vsock device" do
      vm =
        Firecracker.new()
        |> Firecracker.configure(:vsock, guest_cid: 3, uds_path: "/tmp/vsock.sock")

      %{config: config} = Firecracker.dry_run(vm)
      assert %{"vsock" => %{"guest_cid" => 3, "uds_path" => "/tmp/vsock.sock"}} = config
    end

    test "returns configuration for a serial device" do
      vm =
        Firecracker.new()
        |> Firecracker.configure(:serial, output_path: "/tmp/serial.log")

      %{config: config} = Firecracker.dry_run(vm)
      assert %{"serial" => %{"output_path" => "/tmp/serial.log"}} = config
    end

    test "returns configuration for a pmem device" do
      vm =
        Firecracker.new()
        |> Firecracker.add(:pmem, "pmem0",
          path_on_host: "/path/to/pmem.img",
          root_device: false,
          read_only: true
        )

      %{config: config} = Firecracker.dry_run(vm)

      assert %{
               "pmems" => [
                 %{
                   "id" => "pmem0",
                   "path_on_host" => "/path/to/pmem.img",
                   "root_device" => false,
                   "read_only" => true
                 }
               ]
             } = config
    end

    test "returns configuration for multiple pmem devices" do
      vm =
        Firecracker.new()
        |> Firecracker.add(:pmem, "pmem0",
          path_on_host: "/path/to/pmem0.img",
          root_device: true,
          read_only: false
        )
        |> Firecracker.add(:pmem, "pmem1",
          path_on_host: "/path/to/pmem1.img",
          read_only: true
        )

      %{config: config} = Firecracker.dry_run(vm)

      assert %{"pmems" => pmems} = config
      assert length(pmems) == 2

      assert %{
               "id" => "pmem0",
               "path_on_host" => "/path/to/pmem0.img",
               "root_device" => true,
               "read_only" => false
             } in pmems

      assert %{
               "id" => "pmem1",
               "path_on_host" => "/path/to/pmem1.img",
               "read_only" => true
             } in pmems
    end

    test "returns configuration for balloon with stats_polling_interval_s" do
      vm =
        Firecracker.new()
        |> Firecracker.configure(:balloon,
          amount_mib: 100,
          deflate_on_oom: true,
          stats_polling_interval_s: 5
        )

      %{config: config} = Firecracker.dry_run(vm)

      assert %{
               "balloon" => %{
                 "amount_mib" => 100,
                 "deflate_on_oom" => true,
                 "stats_polling_interval_s" => 5
               }
             } = config
    end

    test "returns configuration for a drive" do
      vm =
        Firecracker.new()
        |> Firecracker.add(:drive, "rootfs",
          path_on_host: "/path/to/rootfs.ext4",
          is_root_device: true,
          is_read_only: false
        )

      %{config: config} = Firecracker.dry_run(vm)

      assert %{
               "drives" => [
                 %{
                   "drive_id" => "rootfs",
                   "path_on_host" => "/path/to/rootfs.ext4",
                   "is_root_device" => true,
                   "is_read_only" => false
                 }
               ]
             } = config
    end

    test "returns configuration for multiple drives" do
      vm =
        Firecracker.new()
        |> Firecracker.add(:drive, "rootfs",
          path_on_host: "/path/to/rootfs.ext4",
          is_root_device: true,
          is_read_only: false
        )
        |> Firecracker.add(:drive, "data",
          path_on_host: "/path/to/data.ext4",
          is_root_device: false,
          is_read_only: true
        )

      %{config: config} = Firecracker.dry_run(vm)

      assert %{"drives" => drives} = config
      assert length(drives) == 2

      assert %{
               "drive_id" => "rootfs",
               "path_on_host" => "/path/to/rootfs.ext4",
               "is_root_device" => true,
               "is_read_only" => false
             } in drives

      assert %{
               "drive_id" => "data",
               "path_on_host" => "/path/to/data.ext4",
               "is_root_device" => false,
               "is_read_only" => true
             } in drives
    end

    test "returns configuration for a network interface" do
      vm =
        Firecracker.new()
        |> Firecracker.add(:network_interface, "eth0",
          host_dev_name: "tap0",
          guest_mac: "AA:FC:00:00:00:01"
        )

      %{config: config} = Firecracker.dry_run(vm)

      assert %{
               "network-interfaces" => [
                 %{
                   "iface_id" => "eth0",
                   "host_dev_name" => "tap0",
                   "guest_mac" => "AA:FC:00:00:00:01"
                 }
               ]
             } = config
    end

    test "returns configuration for multiple network interfaces" do
      vm =
        Firecracker.new()
        |> Firecracker.add(:network_interface, "eth0",
          host_dev_name: "tap0",
          guest_mac: "AA:FC:00:00:00:01"
        )
        |> Firecracker.add(:network_interface, "eth1",
          host_dev_name: "tap1",
          guest_mac: "AA:FC:00:00:00:02"
        )

      %{config: config} = Firecracker.dry_run(vm)

      assert %{"network-interfaces" => interfaces} = config
      assert length(interfaces) == 2

      assert %{
               "iface_id" => "eth0",
               "host_dev_name" => "tap0",
               "guest_mac" => "AA:FC:00:00:00:01"
             } in interfaces

      assert %{
               "iface_id" => "eth1",
               "host_dev_name" => "tap1",
               "guest_mac" => "AA:FC:00:00:00:02"
             } in interfaces
    end

    test "returns configuration for network interface with rate limiter" do
      rate_limiter =
        Firecracker.RateLimiter.new()
        |> Firecracker.RateLimiter.bandwidth(
          size: 1_000_000,
          refill_time: 100,
          one_time_burst: 500_000
        )
        |> Firecracker.RateLimiter.ops(
          size: 10_000,
          refill_time: 50,
          one_time_burst: 5_000
        )

      vm =
        Firecracker.new()
        |> Firecracker.add(:network_interface, "eth0",
          host_dev_name: "tap0",
          guest_mac: "AA:FC:00:00:00:01",
          rx_rate_limiter: rate_limiter
        )

      %{config: config} = Firecracker.dry_run(vm)

      assert %{
               "network-interfaces" => [
                 %{
                   "iface_id" => "eth0",
                   "rx_rate_limiter" => %{
                     "bandwidth" => %{
                       "size" => 1_000_000,
                       "refill_time" => 100,
                       "one_time_burst" => 500_000
                     },
                     "ops" => %{
                       "size" => 10_000,
                       "refill_time" => 50,
                       "one_time_burst" => 5_000
                     }
                   }
                 }
               ]
             } = config
    end

    test "returns configuration for entropy" do
      rate_limiter =
        Firecracker.RateLimiter.new()
        |> Firecracker.RateLimiter.ops(
          size: 10_000,
          refill_time: 60,
          one_time_burst: 5_000
        )

      vm =
        Firecracker.new()
        |> Firecracker.configure(:entropy, rate_limiter: rate_limiter)

      %{config: config} = Firecracker.dry_run(vm)

      assert %{
               "entropy" => %{
                 "rate_limiter" => %{
                   "ops" => %{
                     "size" => 10_000,
                     "refill_time" => 60,
                     "one_time_burst" => 5_000
                   }
                 }
               }
             } = config
    end

    test "returns configuration for mmds metadata" do
      vm =
        Firecracker.new()
        |> Firecracker.metadata("instance_id", "i-1234567890")
        |> Firecracker.metadata("region", "us-west-2")

      %{config: config} = Firecracker.dry_run(vm)

      assert %{
               "mmds" => %{
                 "instance_id" => "i-1234567890",
                 "region" => "us-west-2"
               }
             } = config
    end

    test "returns configuration for nested mmds metadata" do
      nested_metadata = %{
        "instance" => %{
          "id" => "i-1234567890",
          "type" => "m5.large"
        },
        "tags" => ["web", "production"]
      }

      vm =
        Firecracker.new()
        |> Firecracker.metadata(nested_metadata)

      %{config: config} = Firecracker.dry_run(vm)

      assert %{
               "mmds" => %{
                 "instance" => %{
                   "id" => "i-1234567890",
                   "type" => "m5.large"
                 },
                 "tags" => ["web", "production"]
               }
             } = config
    end

    @tag tap: "tap0", feature: [:pmem, :serial]
    test "returns complete configuration with all resource types" do
      rate_limiter =
        Firecracker.RateLimiter.new()
        |> Firecracker.RateLimiter.ops(size: 10_000, refill_time: 60)

      vm =
        Firecracker.new()
        |> Firecracker.configure(:boot_source,
          kernel_image_path: "/path/to/kernel",
          boot_args: "console=ttyS0"
        )
        |> Firecracker.add(:drive, "rootfs",
          path_on_host: "/path/to/rootfs.ext4",
          is_root_device: true,
          is_read_only: false
        )
        |> Firecracker.add(:network_interface, "eth0",
          host_dev_name: "tap0",
          guest_mac: "AA:FC:00:00:00:01"
        )
        |> Firecracker.configure(:machine_config, vcpu_count: 4, mem_size_mib: 2048)
        |> Firecracker.configure(:balloon, amount_mib: 256, deflate_on_oom: true)
        |> Firecracker.configure(:cpu_config, kvm_capabilities: ["!56"])
        |> Firecracker.configure(:entropy, rate_limiter: rate_limiter)
        |> Firecracker.configure(:logger, log_path: "/tmp/fc.log", level: "Info")
        |> Firecracker.configure(:metrics, metrics_path: "/tmp/metrics.fifo")
        |> Firecracker.configure(:mmds_config, network_interfaces: ["eth0"])
        |> Firecracker.metadata("instance_id", "i-1234567890")
        |> Firecracker.configure(:serial, output_path: "/tmp/serial.log")
        |> Firecracker.configure(:vsock, guest_cid: 42, uds_path: "/tmp/fc.vsock")
        |> Firecracker.add(:pmem, "pmem0", path_on_host: "/path/to/pmem.img")

      %{config: config} = Firecracker.dry_run(vm)

      # Verify all resources are present in the configuration
      assert %{"boot-source" => %{"kernel_image_path" => "/path/to/kernel"}} = config
      assert %{"drives" => [%{"drive_id" => "rootfs"}]} = config
      assert %{"network-interfaces" => [%{"iface_id" => "eth0"}]} = config
      assert %{"machine-config" => %{"vcpu_count" => 4, "mem_size_mib" => 2048}} = config
      assert %{"balloon" => %{"amount_mib" => 256, "deflate_on_oom" => true}} = config
      assert %{"cpu-config" => %{"kvm_capabilities" => ["!56"]}} = config
      assert %{"entropy" => %{"rate_limiter" => _}} = config
      assert %{"logger" => %{"log_path" => "/tmp/fc.log", "level" => "Info"}} = config
      assert %{"metrics" => %{"metrics_path" => "/tmp/metrics.fifo"}} = config
      assert %{"mmds-config" => %{"network_interfaces" => ["eth0"]}} = config
      assert %{"mmds" => %{"instance_id" => "i-1234567890"}} = config
      assert %{"serial" => %{"output_path" => "/tmp/serial.log"}} = config
      assert %{"vsock" => %{"guest_cid" => 42, "uds_path" => "/tmp/fc.vsock"}} = config
      assert %{"pmems" => [%{"id" => "pmem0"}]} = config
    end
  end

  describe "start/1 full runs" do
    @describetag :vm

    setup context do
      with :ok <- TestRequirements.check(context) do
        :ok
      end
    end

    test "starts a vm using the default firecracker path" do
      vm =
        Firecracker.new()
        |> Firecracker.start()

      on_exit(fn -> Firecracker.stop(vm) end)

      assert %Firecracker{api_sock: sock, process: %Px{}, state: :started} = vm
      assert File.exists?(sock)

      assert [] = vm.errors

      assert %{"id" => "anonymous-instance" <> _, "state" => "Not started"} =
               Firecracker.describe(vm)
    end

    test "starts a vm with a custom :api_sock" do
      vm =
        Firecracker.new()
        |> Firecracker.set_option(:api_sock, "/tmp/fire.sock")
        |> Firecracker.start()

      on_exit(fn -> Firecracker.stop(vm) end)

      assert %Firecracker{api_sock: "/tmp/fire.sock" = sock, process: %Px{}, state: :started} = vm
      assert File.exists?(sock)

      assert [] = vm.errors

      assert %{"id" => "anonymous-instance" <> _, "state" => "Not started"} =
               Firecracker.describe(vm)
    end

    test "starts a vm with a custom :id" do
      vm =
        Firecracker.new()
        |> Firecracker.set_option(:id, "my-vmm")
        |> Firecracker.start()

      on_exit(fn -> Firecracker.stop(vm) end)

      assert %Firecracker{api_sock: sock, id: "my-vmm", process: %Px{}, state: :started} = vm
      assert File.exists?(sock)

      assert [] = vm.errors

      assert %{"id" => "my-vmm", "state" => "Not started"} = Firecracker.describe(vm)
    end

    test "starts a vm with no_api set" do
      vm =
        Firecracker.new()
        |> Firecracker.set_option(:no_api, true)
        |> Firecracker.start()

      on_exit(fn -> Firecracker.stop(vm) end)

      assert [] = vm.errors

      assert %Firecracker{api_sock: nil, process: %Px{}, state: :started} = vm
    end

    @boolean_flags [:boot_timer, :no_seccomp, :show_level, :show_log_origin]
    for flag <- @boolean_flags do
      test "starts a vm with flag #{flag} set" do
        vm =
          Firecracker.new()
          |> Firecracker.set_option(unquote(flag), true)
          |> Firecracker.start()

        on_exit(fn -> Firecracker.stop(vm) end)

        assert %Firecracker{api_sock: sock, process: %Px{}, state: :started} = vm
        assert File.exists?(sock)

        assert [] = vm.errors

        assert %{"id" => "anonymous-instance" <> _, "state" => "Not started"} =
                 Firecracker.describe(vm)
      end
    end

    test "starts a vm with a balloon device" do
      vm =
        Firecracker.new()
        |> Firecracker.configure(:balloon, amount_mib: 10, deflate_on_oom: true)
        |> Firecracker.start()

      on_exit(fn -> Firecracker.stop(vm) end)

      assert %Firecracker{api_sock: sock, process: %Px{}, state: :started} = vm
      assert File.exists?(sock)

      assert [] = vm.errors

      assert %{
               "balloon" => %{
                 "amount_mib" => 10,
                 "deflate_on_oom" => true,
                 "stats_polling_interval_s" => 0
               }
             } = Firecracker.describe(vm, :vm_config)

      assert %{"amount_mib" => 10, "deflate_on_oom" => true, "stats_polling_interval_s" => 0} =
               Firecracker.describe(vm, :balloon)
    end

    test "starts a vm with a boot source" do
      vm =
        Firecracker.new()
        |> Firecracker.configure(:boot_source,
          kernel_image_path: "test/cache/vmlinux",
          boot_args: "console=ttyS0"
        )
        |> Firecracker.start()

      on_exit(fn -> Firecracker.stop(vm) end)

      assert %Firecracker{api_sock: sock, process: %Px{}, state: :started} = vm
      assert File.exists?(sock)

      assert [] = vm.errors

      assert %{
               "boot-source" => %{
                 "kernel_image_path" => "test/cache/vmlinux",
                 "boot_args" => "console=ttyS0"
               }
             } = Firecracker.describe(vm, :vm_config)
    end

    test "starts a vm with a cpu config" do
      vm =
        Firecracker.new()
        |> Firecracker.configure(:cpu_config,
          msr_modifiers: [%{addr: "0x0AAC", bitmap: "0b1xx1"}]
        )
        |> Firecracker.start()

      on_exit(fn -> Firecracker.stop(vm) end)

      assert %Firecracker{api_sock: sock, process: %Px{}, state: :started} = vm
      assert File.exists?(sock)

      assert [] = vm.errors
    end

    test "starts a vm with logger" do
      log_path = TempFiles.touch!("fc", ".log")

      vm =
        Firecracker.new()
        |> Firecracker.configure(:logger,
          log_path: log_path,
          level: "Info",
          show_level: true
        )
        |> Firecracker.start()

      on_exit(fn -> Firecracker.stop(vm) end)

      assert %Firecracker{
               logger: %Firecracker.Logger{log_path: ^log_path},
               api_sock: sock,
               process: %Px{},
               state: :started
             } = vm

      assert File.exists?(sock)

      assert [] = vm.errors
    end

    test "starts a vm with a machine config" do
      vm =
        Firecracker.new()
        |> Firecracker.configure(:machine_config, vcpu_count: 4, mem_size_mib: 1024)
        |> Firecracker.start()

      on_exit(fn -> Firecracker.stop(vm) end)

      assert %Firecracker{api_sock: sock, process: %Px{}, state: :started} = vm
      assert File.exists?(sock)

      assert [] = vm.errors

      assert %{"machine-config" => %{"vcpu_count" => 4, "mem_size_mib" => 1024}} =
               Firecracker.describe(vm, :vm_config)

      assert %{"vcpu_count" => 4, "mem_size_mib" => 1024} =
               Firecracker.describe(vm, :machine_config)
    end

    test "starts a vm with an mmds config" do
      vm =
        Firecracker.new()
        |> Firecracker.add(:network_interface, "eth0",
          host_dev_name: "tap0",
          guest_mac: "AA:FC:00:00:00:01"
        )
        |> Firecracker.configure(:mmds_config, network_interfaces: ["eth0"], version: "V2")
        |> Firecracker.start()

      on_exit(fn -> Firecracker.stop(vm) end)

      assert %Firecracker{api_sock: sock, process: %Px{}, state: :started} = vm
      assert File.exists?(sock)

      assert [] = vm.errors

      assert %{"mmds-config" => %{"network_interfaces" => ["eth0"], "version" => "V2"}} =
               Firecracker.describe(vm, :vm_config)
    end

    test "starts a vm with a vsock device" do
      vm =
        Firecracker.new()
        |> Firecracker.configure(:vsock, guest_cid: 3, uds_path: "/tmp/vsock.sock")
        |> Firecracker.start()

      on_exit(fn -> Firecracker.stop(vm) end)

      assert %Firecracker{api_sock: sock, process: %Px{}, state: :started} = vm
      assert File.exists?(sock)

      assert [] = vm.errors

      assert %{"vsock" => %{"guest_cid" => 3, "uds_path" => "/tmp/vsock.sock"}} =
               Firecracker.describe(vm, :vm_config)
    end

    test "starts a vm with multiple configurations" do
      vm =
        Firecracker.new()
        |> Firecracker.configure(:machine_config, vcpu_count: 4, mem_size_mib: 1024)
        |> Firecracker.configure(:balloon, amount_mib: 1, deflate_on_oom: true)
        |> Firecracker.start()

      on_exit(fn -> Firecracker.stop(vm) end)

      assert %Firecracker{api_sock: sock, process: %Px{}, state: :started} = vm
      assert File.exists?(sock)

      assert [] = vm.errors

      assert %{"machine-config" => %{"vcpu_count" => 4, "mem_size_mib" => 1024}} =
               Firecracker.describe(vm, :vm_config)

      assert %{"amount_mib" => 1, "deflate_on_oom" => true, "stats_polling_interval_s" => 0} =
               Firecracker.describe(vm, :balloon)
    end

    test "is a no-op when starting an already started VM" do
      vm =
        Firecracker.new()
        |> Firecracker.start()

      on_exit(fn -> Firecracker.stop(vm) end)

      assert %Firecracker{state: :started} = vm
      assert %Firecracker{state: :started} = Firecracker.start(vm)
    end

    test "starts a vm with a drive" do
      vm =
        Firecracker.new()
        |> Firecracker.add(:drive, "rootfs",
          path_on_host: FirecrackerHelpers.fetch_rootfs!(),
          is_root_device: true,
          is_read_only: false
        )
        |> Firecracker.start()

      on_exit(fn -> Firecracker.stop(vm) end)

      assert [] = vm.errors

      assert %Firecracker{state: :started} = vm
      assert %{"drives" => [%{"drive_id" => "rootfs"}]} = Firecracker.describe(vm, :vm_config)
    end

    @tag tap: "tap0"
    test "starts a vm with a network interface" do
      vm =
        Firecracker.new()
        |> Firecracker.add(:network_interface, "eth0",
          host_dev_name: "tap0",
          guest_mac: "AA:FC:00:00:00:01"
        )
        |> Firecracker.start()

      on_exit(fn -> Firecracker.stop(vm) end)

      assert %Firecracker{state: :started} = vm

      assert [] = vm.errors

      assert %{"network-interfaces" => [%{"iface_id" => "eth0"}]} =
               Firecracker.describe(vm, :vm_config)
    end

    test "starts a vm with :http_api_max_payload_size option" do
      vm =
        Firecracker.new()
        |> Firecracker.set_option(:http_api_max_payload_size, 102_400)
        |> Firecracker.start()

      on_exit(fn -> Firecracker.stop(vm) end)

      assert [] = vm.errors

      assert %Firecracker{api_sock: sock, process: %Px{}, state: :started} = vm
      assert File.exists?(sock)
    end

    test "starts a vm with :level option" do
      vm =
        Firecracker.new()
        |> Firecracker.set_option(:level, "Debug")

      %{args: args} = Firecracker.dry_run(vm)
      assert "--level" in args
      assert "Debug" in args

      vm = Firecracker.start(vm)
      on_exit(fn -> Firecracker.stop(vm) end)

      assert [] = vm.errors
      assert %Firecracker{api_sock: sock, process: %Px{}, state: :started} = vm
      assert File.exists?(sock)
    end

    test "starts a vm with :log_path option" do
      log_path = TempFiles.touch!("fc-test", ".log")

      vm =
        Firecracker.new()
        |> Firecracker.set_option(:log_path, log_path)

      %{args: args} = Firecracker.dry_run(vm)
      assert "--log-path" in args
      assert log_path in args

      vm = Firecracker.start(vm)
      on_exit(fn -> Firecracker.stop(vm) end)

      assert %Firecracker{api_sock: sock, process: %Px{}, state: :started} = vm
      assert File.exists?(sock)
      assert [] = vm.errors
    end

    test "starts a vm with :metrics_path option" do
      metrics_path = TempFiles.mkfifo!("fc-metrics")

      vm =
        Firecracker.new()
        |> Firecracker.set_option(:metrics_path, metrics_path)

      # Verify CLI arg is generated (metrics config is not returned by /vm/config)
      %{args: args} = Firecracker.dry_run(vm)
      assert "--metrics-path" in args
      assert metrics_path in args

      vm = Firecracker.start(vm)
      on_exit(fn -> Firecracker.stop(vm) end)

      assert %Firecracker{api_sock: sock, process: %Px{}, state: :started} = vm
      assert File.exists?(sock)
      assert [] = vm.errors
    end

    test "starts a vm with :mmds_size_limit option" do
      vm =
        Firecracker.new()
        |> Firecracker.set_option(:mmds_size_limit, 102_400)
        |> Firecracker.start()

      on_exit(fn -> Firecracker.stop(vm) end)

      assert %Firecracker{api_sock: sock, process: %Px{}, state: :started} = vm
      assert File.exists?(sock)
    end

    test "starts a vm with :module option" do
      vm =
        Firecracker.new()
        |> Firecracker.set_option(:module, "api_server")

      # Verify CLI arg is generated (logger config is not returned by /vm/config)
      %{args: args} = Firecracker.dry_run(vm)
      assert "--module" in args
      assert "api_server" in args

      vm = Firecracker.start(vm)
      on_exit(fn -> Firecracker.stop(vm) end)

      assert %Firecracker{api_sock: sock, process: %Px{}, state: :started} = vm
      assert File.exists?(sock)
      assert [] = vm.errors
    end

    test "starts a vm with :seccomp_filter option" do
      # Create a minimal valid seccomp filter
      filter_content = ~s({
        "main": {
          "default_action": "Allow",
          "filter_action": "Allow",
          "filter": []
        }
      })

      filter_path = TempFiles.write!("custom-seccomp", ".json", filter_content)

      vm =
        Firecracker.new()
        |> Firecracker.set_option(:seccomp_filter, filter_path)
        |> Firecracker.start()

      on_exit(fn -> Firecracker.stop(vm) end)

      assert %Firecracker{api_sock: sock, process: %Px{}, state: :started} = vm
      assert File.exists?(sock)

      assert [] = vm.errors
    end

    test "starts a vm with :parent_cpu_time_us option" do
      vm =
        Firecracker.new()
        |> Firecracker.set_option(:parent_cpu_time_us, 1000)
        |> Firecracker.start()

      on_exit(fn -> Firecracker.stop(vm) end)

      assert %Firecracker{api_sock: sock, process: %Px{}, state: :started} = vm
      assert File.exists?(sock)

      assert [] = vm.errors
    end

    test "starts a vm with :start_time_cpu_us option" do
      vm =
        Firecracker.new()
        |> Firecracker.set_option(:start_time_cpu_us, 1000)
        |> Firecracker.start()

      on_exit(fn -> Firecracker.stop(vm) end)

      assert %Firecracker{api_sock: sock, process: %Px{}, state: :started} = vm
      assert File.exists?(sock)

      assert [] = vm.errors
    end

    test "starts a vm with :start_time_us option" do
      vm =
        Firecracker.new()
        |> Firecracker.set_option(:start_time_us, 1000)
        |> Firecracker.start()

      on_exit(fn -> Firecracker.stop(vm) end)

      assert %Firecracker{api_sock: sock, process: %Px{}, state: :started} = vm
      assert File.exists?(sock)

      assert [] = vm.errors
    end

    test "starts a vm with multiple options combined" do
      log_path = TempFiles.touch!("fc-multi", ".log")

      vm =
        Firecracker.new()
        |> Firecracker.set_option(:log_path, log_path)
        |> Firecracker.set_option(:level, "Debug")
        |> Firecracker.set_option(:show_level, true)
        |> Firecracker.set_option(:show_log_origin, true)
        |> Firecracker.set_option(:http_api_max_payload_size, 102_400)
        |> Firecracker.start()

      on_exit(fn -> Firecracker.stop(vm) end)

      assert %Firecracker{api_sock: sock, process: %Px{}, state: :started} = vm
      assert File.exists?(sock)

      assert [] = vm.errors
    end

    test "starts a vm with entropy device" do
      vm =
        Firecracker.new()
        |> Firecracker.configure(:entropy, [])
        |> Firecracker.start()

      on_exit(fn -> Firecracker.stop(vm) end)

      assert %Firecracker{api_sock: sock, process: %Px{}, state: :started} = vm
      assert File.exists?(sock)

      assert [] = vm.errors

      assert %{"entropy" => _} = Firecracker.describe(vm, :vm_config)
    end

    test "starts a vm with entropy device with rate limiter" do
      rate_limiter =
        Firecracker.RateLimiter.new(
          bandwidth: [size: 10_000_000, refill_time: 100],
          ops: [size: 1000, refill_time: 1000]
        )

      vm =
        Firecracker.new()
        |> Firecracker.configure(:entropy, rate_limiter: rate_limiter)
        |> Firecracker.start()

      on_exit(fn -> Firecracker.stop(vm) end)

      assert %Firecracker{api_sock: sock, process: %Px{}, state: :started} = vm
      assert File.exists?(sock)

      assert [] = vm.errors

      config = Firecracker.describe(vm, :vm_config)
      assert %{"entropy" => %{"rate_limiter" => _}} = config
    end

    @tag feature: :serial
    test "starts a vm with serial device" do
      vm =
        Firecracker.new()
        |> Firecracker.configure(:serial, [])
        |> Firecracker.start()

      on_exit(fn -> Firecracker.stop(vm) end)

      assert [] = vm.errors

      assert %Firecracker{api_sock: sock, process: %Px{}, state: :started} = vm
      assert File.exists?(sock)
    end

    @tag feature: :pmem
    test "starts a vm with pmem device" do
      pmem_file = TempFiles.write!("pmem", ".img", :binary.copy(<<0>>, 1024 * 1024))

      vm =
        Firecracker.new()
        |> Firecracker.add(:pmem, "pmem0", path_on_host: pmem_file)
        |> Firecracker.start()

      on_exit(fn -> Firecracker.stop(vm) end)

      assert %Firecracker{api_sock: sock, process: %Px{}, state: :started} = vm
      assert File.exists?(sock)

      assert [] = vm.errors

      assert %{"pmems" => [%{"id" => "pmem0"}]} = Firecracker.describe(vm, :vm_config)
    end

    @tag feature: :pmem
    test "starts a vm with multiple pmem devices" do
      pmem_file1 = TempFiles.write!("pmem1", ".img", :binary.copy(<<0>>, 1024 * 1024))
      pmem_file2 = TempFiles.write!("pmem2", ".img", :binary.copy(<<0>>, 1024 * 1024))

      vm =
        Firecracker.new()
        |> Firecracker.add(:pmem, "pmem0", path_on_host: pmem_file1)
        |> Firecracker.add(:pmem, "pmem1", path_on_host: pmem_file2)
        |> Firecracker.start()

      on_exit(fn -> Firecracker.stop(vm) end)

      assert %Firecracker{api_sock: sock, process: %Px{}, state: :started} = vm
      assert File.exists?(sock)

      assert [] = vm.errors

      config = Firecracker.describe(vm, :vm_config)
      assert %{"pmems" => pmems} = config
      assert length(pmems) == 2
      assert Enum.any?(pmems, &(&1["id"] == "pmem0"))
      assert Enum.any?(pmems, &(&1["id"] == "pmem1"))
    end

    test "starts a vm with metrics configuration" do
      metrics_path = TempFiles.mkfifo!("fc-metrics-cfg")

      vm =
        Firecracker.new()
        |> Firecracker.configure(:metrics, metrics_path: metrics_path)
        |> Firecracker.start()

      on_exit(fn -> Firecracker.stop(vm) end)

      assert [] = vm.errors

      assert %Firecracker{api_sock: sock, process: %Px{}, state: :started} = vm
      assert File.exists?(sock)
    end

    test "starts a vm with multiple drives" do
      rootfs = FirecrackerHelpers.fetch_rootfs!()
      drive2_path = TempFiles.write!("drive2", ".img", :binary.copy(<<0>>, 1024 * 1024))

      vm =
        Firecracker.new()
        |> Firecracker.add(:drive, "rootfs",
          path_on_host: rootfs,
          is_root_device: true,
          is_read_only: false
        )
        |> Firecracker.add(:drive, "data",
          path_on_host: drive2_path,
          is_root_device: false,
          is_read_only: false
        )
        |> Firecracker.start()

      on_exit(fn -> Firecracker.stop(vm) end)

      assert %Firecracker{state: :started} = vm

      assert [] = vm.errors

      config = Firecracker.describe(vm, :vm_config)
      assert %{"drives" => drives} = config
      assert length(drives) == 2
      assert Enum.any?(drives, &(&1["drive_id"] == "rootfs"))
      assert Enum.any?(drives, &(&1["drive_id"] == "data"))
    end

    @tag tap: ["tap0", "tap1"]
    test "starts a vm with multiple network interfaces" do
      vm =
        Firecracker.new()
        |> Firecracker.add(:network_interface, "eth0",
          host_dev_name: "tap0",
          guest_mac: "AA:FC:00:00:00:01"
        )
        |> Firecracker.add(:network_interface, "eth1",
          host_dev_name: "tap1",
          guest_mac: "AA:FC:00:00:00:02"
        )
        |> Firecracker.start()

      on_exit(fn -> Firecracker.stop(vm) end)

      assert %Firecracker{state: :started} = vm

      assert [] = vm.errors

      config = Firecracker.describe(vm, :vm_config)
      assert %{"network-interfaces" => interfaces} = config
      assert length(interfaces) == 2
      assert Enum.any?(interfaces, &(&1["iface_id"] == "eth0"))
      assert Enum.any?(interfaces, &(&1["iface_id"] == "eth1"))
    end

    test "starts a vm with metadata set before start" do
      vm =
        Firecracker.new()
        |> Firecracker.metadata("hostname", "test-vm")
        |> Firecracker.metadata("environment", "test")
        |> Firecracker.start()

      on_exit(fn -> Firecracker.stop(vm) end)

      assert %Firecracker{api_sock: sock, process: %Px{}, state: :started} = vm
      assert File.exists?(sock)

      assert [] = vm.errors

      metadata = Firecracker.describe(vm, :mmds)
      assert %{"hostname" => "test-vm", "environment" => "test"} = metadata
    end

    test "starts a vm with complete metadata map" do
      metadata_map = %{
        "user_data" => "#!/bin/bash\necho 'Hello'",
        "instance_id" => "i-1234",
        "config" => %{
          "key1" => "value1",
          "key2" => "value2"
        }
      }

      vm =
        Firecracker.new()
        |> Firecracker.metadata(metadata_map)
        |> Firecracker.start()

      on_exit(fn -> Firecracker.stop(vm) end)

      assert %Firecracker{api_sock: sock, process: %Px{}, state: :started} = vm
      assert File.exists?(sock)

      assert [] = vm.errors

      metadata = Firecracker.describe(vm, :mmds)
      assert %{"user_data" => _, "instance_id" => "i-1234", "config" => _} = metadata
    end

    test "starts a vm with nested metadata structures" do
      vm =
        Firecracker.new()
        |> Firecracker.metadata(%{
          "deeply" => %{
            "nested" => %{
              "structure" => %{
                "value" => "test"
              }
            }
          }
        })
        |> Firecracker.start()

      on_exit(fn -> Firecracker.stop(vm) end)

      assert %Firecracker{api_sock: sock, process: %Px{}, state: :started} = vm
      assert File.exists?(sock)

      assert [] = vm.errors

      metadata = Firecracker.describe(vm, :mmds)
      assert %{"deeply" => %{"nested" => %{"structure" => %{"value" => "test"}}}} = metadata
    end

    test "starts a vm with config_file option" do
      config = %{
        "machine-config" => %{
          "vcpu_count" => 2,
          "mem_size_mib" => 512
        }
      }

      config_path = TempFiles.write!("fc-config", ".json", :json.encode(config))

      vm =
        Firecracker.new()
        |> Firecracker.set_option(:config_file, config_path)
        |> Firecracker.start()

      on_exit(fn -> Firecracker.stop(vm) end)

      assert %Firecracker{
               api_sock: sock,
               config_file: ^config_path,
               process: %Px{},
               state: :started
             } = vm

      assert File.exists?(sock)

      assert [] = vm.errors

      assert %{"vcpu_count" => 2, "mem_size_mib" => 512} =
               Firecracker.describe(vm, :machine_config)
    end

    test "starts a vm with no_api and auto-generated config file" do
      vm =
        Firecracker.new()
        |> Firecracker.set_option(:no_api, true)
        |> Firecracker.configure(:machine_config, vcpu_count: 3, mem_size_mib: 256)
        |> Firecracker.start()

      on_exit(fn -> Firecracker.stop(vm) end)

      assert %Firecracker{
               api_sock: nil,
               config_file: config_file,
               no_api: true,
               process: %Px{},
               state: :started
             } = vm

      assert config_file != nil
      assert File.exists?(config_file)
      assert String.contains?(config_file, vm.id)
    end

    test "starts a vm with basic jailer configuration" do
      chroot_dir = TempFiles.mkdir_p!("jailer-basic")

      vm =
        Firecracker.new()
        |> Firecracker.jail(uid: 1000, gid: 1000, chroot_base_dir: chroot_dir)
        |> Firecracker.start()

      on_exit(fn -> Firecracker.stop(vm) end)

      assert %Firecracker{
               jailer: %Firecracker.Jailer{uid: 1000, gid: 1000},
               process: %Px{},
               state: :started
             } = vm
    end

    test "starts a vm with jailer and chroot_base_dir" do
      chroot_dir = TempFiles.mkdir_p!("jailer-test")

      vm =
        Firecracker.new()
        |> Firecracker.jail(uid: 1000, gid: 1000, chroot_base_dir: chroot_dir)
        |> Firecracker.start()

      on_exit(fn -> Firecracker.stop(vm) end)

      assert %Firecracker{
               jailer: %Firecracker.Jailer{chroot_base_dir: ^chroot_dir},
               process: %Px{},
               state: :started
             } = vm
    end

    test "starts a vm with jailer and cgroup configuration" do
      chroot_dir = TempFiles.mkdir_p!("jailer-cgroup")

      vm =
        Firecracker.new()
        |> Firecracker.jail(uid: 1000, gid: 1000, chroot_base_dir: chroot_dir)
        |> Firecracker.cgroup("memory.limit_in_bytes", "512M")
        |> Firecracker.cgroup("cpu.cfs_quota_us", "100000")
        |> Firecracker.start()

      on_exit(fn -> Firecracker.stop(vm) end)

      assert %Firecracker{
               jailer: %Firecracker.Jailer{
                 cgroups: %{
                   "memory.limit_in_bytes" => "512M",
                   "cpu.cfs_quota_us" => "100000"
                 }
               },
               process: %Px{},
               state: :started
             } = vm
    end

    test "starts a vm with jailer and resource limits" do
      chroot_dir = TempFiles.mkdir_p!("jailer-rlimits")

      vm =
        Firecracker.new()
        |> Firecracker.jail(uid: 1000, gid: 1000, chroot_base_dir: chroot_dir)
        |> Firecracker.resource_limit("fsize", 1024 * 1024 * 1024)
        |> Firecracker.resource_limit("no-file", 1024)
        |> Firecracker.start()

      on_exit(fn -> Firecracker.stop(vm) end)

      assert %Firecracker{
               jailer: %Firecracker.Jailer{
                 resource_limits: %{
                   "fsize" => _,
                   "no-file" => 1024
                 }
               },
               process: %Px{},
               state: :started
             } = vm
    end

    test "starts a vm with jailer and all options" do
      chroot_dir = TempFiles.mkdir_p!("jailer-full")

      vm =
        Firecracker.new()
        |> Firecracker.jail(
          uid: 1000,
          gid: 1000,
          chroot_base_dir: chroot_dir,
          cgroup_version: "2"
        )
        |> Firecracker.cgroup("memory.limit_in_bytes", "512M")
        |> Firecracker.resource_limit("fsize", 1024 * 1024 * 1024)
        |> Firecracker.start()

      on_exit(fn -> Firecracker.stop(vm) end)

      assert %Firecracker{
               jailer: %Firecracker.Jailer{
                 uid: 1000,
                 gid: 1000,
                 cgroup_version: "2",
                 cgroups: %{"memory.limit_in_bytes" => "512M"},
                 resource_limits: %{"fsize" => _}
               },
               process: %Px{},
               state: :started
             } = vm
    end

    test "raises when trying to start VM from :running state" do
      vm =
        Firecracker.new()
        |> Firecracker.start()

      on_exit(fn -> Firecracker.stop(vm) end)

      # Manually set state to :running (simulating a booted VM)
      running_vm = %{vm | state: :running}

      assert_raise ArgumentError, ~r/unable to start VM which is in :running state/, fn ->
        Firecracker.start(running_vm)
      end
    end

    test "raises when trying to start VM from :paused state" do
      paused_vm = %Firecracker{state: :paused}

      assert_raise ArgumentError, ~r/unable to start VM which is in :paused state/, fn ->
        Firecracker.start(paused_vm)
      end
    end

    test "raises when trying to start VM from :exited state" do
      exited_vm = %Firecracker{state: :exited}

      assert_raise ArgumentError, ~r/unable to start VM which is in :exited state/, fn ->
        Firecracker.start(exited_vm)
      end
    end

    test "raises when firecracker binary does not exist" do
      vm =
        Firecracker.new()
        |> Firecracker.set_option(:firecracker_path, "/nonexistent/firecracker")

      assert_raise RuntimeError, fn ->
        Firecracker.start(vm)
      end
    end

    test "raises when firecracker process dies immediately" do
      vm =
        Firecracker.new()
        |> Firecracker.set_option(:api_sock, "/invalid/path/that/does/not/exist/sock")

      assert_raise RuntimeError, ~r/Failed to start Firecracker/, fn ->
        Firecracker.start(vm)
      end
    end

    test "handles missing permissions gracefully" do
      # Create a directory without write permissions
      restricted_dir = TempFiles.mkdir_p!("restricted")
      File.chmod!(restricted_dir, 0o444)

      vm =
        Firecracker.new()
        |> Firecracker.set_option(:api_sock, "#{restricted_dir}/firecracker.sock")

      on_exit(fn ->
        # Restore permissions before cleanup (TempFiles.cleanup will remove it)
        File.chmod!(restricted_dir, 0o755)
      end)

      assert_raise RuntimeError, ~r/Failed to start Firecracker/, fn ->
        Firecracker.start(vm)
      end
    end

    @tag [tap: "tap0", feature: [:pmem, :serial]]
    test "starts VM with all device types combined" do
      rootfs = FirecrackerHelpers.fetch_rootfs!()
      pmem_file = TempFiles.write!("pmem-all", ".img", :binary.copy(<<0>>, 1024 * 1024))
      vsock_path = TempFiles.path("vsock-all", ".sock")

      vm =
        Firecracker.new()
        |> Firecracker.configure(:machine_config, vcpu_count: 2, mem_size_mib: 512)
        |> Firecracker.configure(:balloon, amount_mib: 100, deflate_on_oom: true)
        |> Firecracker.configure(:boot_source,
          kernel_image_path: "test/cache/vmlinux",
          boot_args: "console=ttyS0"
        )
        |> Firecracker.configure(:vsock, guest_cid: 3, uds_path: vsock_path)
        |> Firecracker.configure(:entropy, [])
        |> Firecracker.configure(:serial, [])
        |> Firecracker.add(:drive, "rootfs",
          path_on_host: rootfs,
          is_root_device: true,
          is_read_only: false
        )
        |> Firecracker.add(:network_interface, "eth0",
          host_dev_name: "tap0",
          guest_mac: "AA:FC:00:00:00:01"
        )
        |> Firecracker.add(:pmem, "pmem0", path_on_host: pmem_file)
        |> Firecracker.metadata("test", "value")
        |> Firecracker.start()

      on_exit(fn -> Firecracker.stop(vm) end)

      assert %Firecracker{state: :started} = vm

      # Verify all configurations were applied
      vm_config = Firecracker.describe(vm, :vm_config)
      assert %{"machine-config" => %{"vcpu_count" => 2}} = vm_config
      assert %{"drives" => [%{"drive_id" => "rootfs"}]} = vm_config
      assert %{"network-interfaces" => [%{"iface_id" => "eth0"}]} = vm_config
      assert %{"pmems" => [%{"id" => "pmem0"}]} = vm_config
      assert %{"vsock" => %{"guest_cid" => 3}} = vm_config
      assert %{"entropy" => _} = vm_config

      balloon = Firecracker.describe(vm, :balloon)
      assert %{"amount_mib" => 100} = balloon

      metadata = Firecracker.describe(vm, :mmds)
      assert %{"test" => "value"} = metadata
    end

    test "starts VM with custom firecracker_path" do
      custom_path = Firecracker.which()

      vm =
        Firecracker.new()
        |> Firecracker.set_option(:firecracker_path, custom_path)
        |> Firecracker.start()

      on_exit(fn -> Firecracker.stop(vm) end)

      assert %Firecracker{
               firecracker_path: ^custom_path,
               process: %Px{},
               state: :started
             } = vm
    end

    test "socket cleanup on stop after start" do
      vm =
        Firecracker.new()
        |> Firecracker.start()

      sock_path = vm.api_sock
      assert File.exists?(sock_path)

      Firecracker.stop(vm)

      # Socket should be cleaned up
      refute File.exists?(sock_path)
    end

    test "vsock cleanup on stop after start" do
      vsock_path = TempFiles.path("vsock-cleanup", ".sock")

      vm =
        Firecracker.new()
        |> Firecracker.configure(:vsock, guest_cid: 3, uds_path: vsock_path)
        |> Firecracker.start()

      assert File.exists?(vm.api_sock)
      assert File.exists?(vsock_path)

      Firecracker.stop(vm)

      refute File.exists?(vm.api_sock)
      refute File.exists?(vsock_path)
    end

    test "metrics file cleanup on stop after start" do
      metrics_path = TempFiles.mkfifo!("metrics-cleanup")

      vm =
        Firecracker.new()
        |> Firecracker.configure(:metrics, metrics_path: metrics_path)
        |> Firecracker.start()

      assert File.exists?(vm.api_sock)
      assert File.exists?(metrics_path)

      Firecracker.stop(vm)

      refute File.exists?(vm.api_sock)
      refute File.exists?(metrics_path)
    end

    @tag feature: :serial
    test "serial output cleanup on stop after start" do
      serial_path = TempFiles.touch!("serial-cleanup", ".log")

      vm =
        Firecracker.new()
        |> Firecracker.configure(:serial, output_path: serial_path)
        |> Firecracker.start()

      assert File.exists?(vm.api_sock)
      assert File.exists?(serial_path)

      Firecracker.stop(vm)

      refute File.exists?(vm.api_sock)
      refute File.exists?(serial_path)
    end

    test "preserves log files on stop" do
      log_path = TempFiles.touch!("log-preserve", ".log")

      vm =
        Firecracker.new()
        |> Firecracker.configure(:logger, log_path: log_path, level: "Info")
        |> Firecracker.start()

      assert File.exists?(vm.api_sock)
      assert File.exists?(log_path)

      Firecracker.stop(vm)

      refute File.exists?(vm.api_sock)
      assert File.exists?(log_path)
    end
  end

  describe "apply/1 pre-boot" do
    @describetag :vm

    setup context do
      with :ok <- TestRequirements.check(context) do
        vm = Firecracker.new() |> Firecracker.start()

        on_exit(fn -> Firecracker.stop(vm) end)

        kernel = FirecrackerHelpers.fetch_kernel!()
        rootfs = FirecrackerHelpers.fetch_rootfs!()

        [vm: vm, kernel: kernel, rootfs: rootfs]
      end
    end

    test "applies drive configuration before boot", %{vm: vm, rootfs: rootfs} do
      updated_vm =
        vm
        |> Firecracker.add(:drive, "rootfs",
          path_on_host: rootfs,
          is_root_device: true,
          is_read_only: false
        )
        |> Firecracker.apply()

      assert [] = updated_vm.errors
      assert updated_vm.drives["rootfs"].applied? == true
    end

    @tag tap: "tap0"
    test "applies network_interface configuration before boot", %{vm: vm} do
      updated_vm =
        vm
        |> Firecracker.add(:network_interface, "eth0",
          host_dev_name: "tap0",
          guest_mac: "aa:fc:00:00:00:01"
        )
        |> Firecracker.apply()

      assert [] = updated_vm.errors
      assert updated_vm.network_interfaces["eth0"].applied? == true
    end

    test "applies balloon configuration before boot", %{vm: vm} do
      updated_vm =
        vm
        |> Firecracker.configure(:balloon, amount_mib: 5, deflate_on_oom: true)
        |> Firecracker.apply()

      assert [] = updated_vm.errors
      assert updated_vm.balloon.applied? == true

      balloon_config = Firecracker.describe(updated_vm, :balloon)
      assert %{"amount_mib" => 5, "deflate_on_oom" => true} = balloon_config
    end

    test "applies boot_source configuration before boot", %{vm: vm, kernel: kernel} do
      updated_vm =
        vm
        |> Firecracker.configure(:boot_source, kernel_image_path: kernel)
        |> Firecracker.apply()

      assert [] = updated_vm.errors
      assert updated_vm.boot_source.applied? == true

      boot_config = Firecracker.describe(updated_vm, :boot_source)
      assert %{"kernel_image_path" => ^kernel} = boot_config
    end

    test "applies cpu_config configuration before boot", %{vm: vm} do
      updated_vm =
        vm
        |> Firecracker.configure(:cpu_config, kvm_capabilities: ["!56"])
        |> Firecracker.apply()

      assert [] = updated_vm.errors
      assert updated_vm.cpu_config.applied? == true
    end

    test "applies entropy configuration before boot", %{vm: vm} do
      rate_limiter =
        Firecracker.RateLimiter.new()
        |> Firecracker.RateLimiter.ops(
          size: 10_000,
          refill_time: 60,
          one_time_burst: 5_000
        )

      updated_vm =
        vm
        |> Firecracker.configure(:entropy, rate_limiter: rate_limiter)
        |> Firecracker.apply()

      assert [] = updated_vm.errors
      assert updated_vm.entropy.applied? == true

      # TODO: describe?
    end

    test "applies logger configuration before boot", %{vm: vm} do
      log_path = TempFiles.touch!("firecracker", ".log")

      updated_vm =
        vm
        |> Firecracker.configure(:logger, level: "Debug", log_path: log_path)
        |> Firecracker.apply()

      assert [] = updated_vm.errors
      assert updated_vm.logger.applied? == true
      assert updated_vm.logger.level == "Debug"
      assert updated_vm.logger.log_path == log_path
    end

    test "applies machine_config configuration before boot", %{vm: vm} do
      updated_vm =
        vm
        |> Firecracker.configure(:machine_config, vcpu_count: 2, mem_size_mib: 512)
        |> Firecracker.apply()

      assert [] = updated_vm.errors
      assert updated_vm.machine_config.applied? == true

      machine_config = Firecracker.describe(updated_vm, :machine_config)
      assert %{"vcpu_count" => 2, "mem_size_mib" => 512} = machine_config
    end

    test "applies metrics configuration before boot", %{vm: vm} do
      fifo = TempFiles.mkfifo!("fc-metrics")

      updated_vm =
        vm
        |> Firecracker.configure(:metrics, metrics_path: fifo)
        |> Firecracker.apply()

      assert [] = updated_vm.errors
      assert updated_vm.metrics.applied? == true
      # Verify struct fields (metrics is not returned by /vm/config)
      assert updated_vm.metrics.metrics_path == fifo
    end

    @tag tap: "tap0"
    test "applies mmds_config configuration before boot", %{vm: vm} do
      updated_vm =
        vm
        |> Firecracker.add(:network_interface, "eth0",
          host_dev_name: "tap0",
          guest_mac: "AA:FC:00:00:00:01"
        )
        |> Firecracker.configure(:mmds_config,
          network_interfaces: ["eth0"],
          ipv4_address: "169.254.169.254"
        )
        |> Firecracker.apply()

      assert [] = updated_vm.errors
      assert updated_vm.mmds_config.applied? == true
    end

    test "applies mmds metadata before boot", %{vm: vm} do
      updated_vm =
        vm
        |> Firecracker.metadata("test_key", "test_value")
        |> Firecracker.apply()

      assert [] = updated_vm.errors
      assert updated_vm.mmds.applied? == true

      metadata = Firecracker.describe(updated_vm, :mmds)
      assert %{"test_key" => "test_value"} = metadata
    end

    @tag feature: :serial
    test "applies serial configuration before boot", %{vm: vm} do
      updated_vm =
        vm
        |> Firecracker.configure(:serial, output_path: "/tmp/serial.log")
        |> Firecracker.apply()

      assert [] = updated_vm.errors
      assert updated_vm.serial.applied? == true
    end

    test "applies vsock configuration before boot", %{vm: vm} do
      updated_vm =
        vm
        |> Firecracker.configure(:vsock, guest_cid: 3, uds_path: "/tmp/firecracker.vsock")
        |> Firecracker.apply()

      assert [] = updated_vm.errors
      assert updated_vm.vsock.applied? == true

      vsock_config = Firecracker.describe(updated_vm, :vsock)
      assert %{"guest_cid" => 3} = vsock_config
    end

    test "applies multiple drives in one apply call", %{vm: vm, rootfs: rootfs} do
      updated_vm =
        vm
        |> Firecracker.add(:drive, "rootfs",
          path_on_host: rootfs,
          is_root_device: true,
          is_read_only: false
        )
        |> Firecracker.add(:drive, "data1",
          path_on_host: "/tmp/data1.ext4",
          is_root_device: false,
          is_read_only: true
        )
        |> Firecracker.apply()

      assert [] = updated_vm.errors
      assert updated_vm.drives["rootfs"].applied? == true
      assert updated_vm.drives["data1"].applied? == true
      assert updated_vm.drives["data2"].applied? == true
    end

    @tag tap: "tap0"
    test "applies multiple network interfaces in one apply call", %{vm: vm} do
      updated_vm =
        vm
        |> Firecracker.add(:network_interface, "eth0",
          host_dev_name: "tap0",
          guest_mac: "AA:FC:00:00:00:01"
        )
        |> Firecracker.add(:network_interface, "eth1",
          host_dev_name: "tap1",
          guest_mac: "AA:FC:00:00:00:02"
        )
        |> Firecracker.apply()

      assert [] = updated_vm.errors
      assert updated_vm.network_interfaces["eth0"].applied? == true
      assert updated_vm.network_interfaces["eth1"].applied? == true
    end

    @tag feature: :pmem
    test "applies multiple pmem devices in one apply call", %{vm: vm} do
      updated_vm =
        vm
        |> Firecracker.add(:pmem, "pmem0", path_on_host: "/tmp/pmem0.img")
        |> Firecracker.add(:pmem, "pmem1", path_on_host: "/tmp/pmem1.img")
        |> Firecracker.apply()

      assert [] = updated_vm.errors
      assert updated_vm.pmems["pmem0"].applied? == true
      assert updated_vm.pmems["pmem1"].applied? == true
    end

    @tag [tap: "tap0", feature: [:pmem, :serial]]
    test "applies all resource types together in one apply call", %{
      vm: vm,
      kernel: kernel,
      rootfs: rootfs
    } do
      rate_limiter =
        Firecracker.RateLimiter.new()
        |> Firecracker.RateLimiter.ops(size: 10_000, refill_time: 60)

      updated_vm =
        vm
        |> Firecracker.add(:drive, "rootfs",
          path_on_host: rootfs,
          is_root_device: true,
          is_read_only: false
        )
        |> Firecracker.add(:drive, "data", path_on_host: "/tmp/data.ext4", is_root_device: false)
        |> Firecracker.add(:network_interface, "eth0",
          host_dev_name: "tap0",
          guest_mac: "AA:FC:00:00:00:01"
        )
        |> Firecracker.add(:network_interface, "eth1",
          host_dev_name: "tap1",
          guest_mac: "AA:FC:00:00:00:02"
        )
        |> Firecracker.add(:pmem, "pmem0", path_on_host: "/tmp/pmem0.img")
        |> Firecracker.configure(:balloon, amount_mib: 256, deflate_on_oom: true)
        |> Firecracker.configure(:boot_source, kernel_image_path: kernel)
        |> Firecracker.configure(:cpu_config, kvm_capabilities: ["!56"])
        |> Firecracker.configure(:entropy, rate_limiter: rate_limiter)
        |> Firecracker.configure(:logger, level: "Info", log_path: "/tmp/fc.log")
        |> Firecracker.configure(:machine_config, vcpu_count: 4, mem_size_mib: 2048)
        |> Firecracker.configure(:metrics, metrics_path: "/tmp/metrics.fifo")
        |> Firecracker.configure(:mmds_config, network_interfaces: ["eth0"])
        |> Firecracker.metadata("instance_id", "i-1234567890")
        |> Firecracker.configure(:serial, output_path: "/tmp/serial.log")
        |> Firecracker.configure(:vsock, guest_cid: 42, uds_path: "/tmp/fc.vsock")
        |> Firecracker.apply()

      assert [] = updated_vm.errors

      # Verify all resources are marked as applied
      assert updated_vm.drives["rootfs"].applied? == true
      assert updated_vm.drives["data"].applied? == true
      assert updated_vm.network_interfaces["eth0"].applied? == true
      assert updated_vm.network_interfaces["eth1"].applied? == true
      assert updated_vm.pmems["pmem0"].applied? == true
      assert updated_vm.balloon.applied? == true
      assert updated_vm.boot_source.applied? == true
      assert updated_vm.cpu_config.applied? == true
      assert updated_vm.entropy.applied? == true
      assert updated_vm.logger.applied? == true
      assert updated_vm.machine_config.applied? == true
      assert updated_vm.metrics.applied? == true
      assert updated_vm.mmds_config.applied? == true
      assert updated_vm.mmds.applied? == true
      assert updated_vm.serial.applied? == true
      assert updated_vm.vsock.applied? == true
    end

    test "applies nested metadata structures before boot", %{vm: vm} do
      nested_metadata = %{
        "instance" => %{
          "id" => "i-1234567890",
          "type" => "m5.large",
          "region" => "us-west-2"
        },
        "user_data" => %{
          "script" => "#!/bin/bash\necho 'hello'",
          "config" => %{
            "enabled" => true,
            "settings" => %{
              "timeout" => 300,
              "retries" => 3
            }
          }
        },
        "tags" => ["web", "production", "v1.0.0"]
      }

      updated_vm =
        vm
        |> Firecracker.metadata(nested_metadata)
        |> Firecracker.apply()

      assert [] = updated_vm.errors
      assert updated_vm.mmds.applied? == true

      metadata = Firecracker.describe(updated_vm, :mmds)
      assert %{"instance" => %{"id" => "i-1234567890", "type" => "m5.large"}} = metadata
      assert %{"user_data" => %{"config" => %{"settings" => %{"timeout" => 300}}}} = metadata
      assert %{"tags" => ["web", "production", "v1.0.0"]} = metadata
    end

    test "chains configure/apply calls and only applies unapplied changes", %{
      vm: vm,
      kernel: kernel,
      rootfs: rootfs
    } do
      # First configure and apply
      vm =
        vm
        |> Firecracker.configure(:boot_source, kernel_image_path: kernel)
        |> Firecracker.add(:drive, "rootfs",
          path_on_host: rootfs,
          is_root_device: true,
          is_read_only: false
        )
        |> Firecracker.apply()

      assert [] = vm.errors
      assert vm.boot_source.applied? == true
      assert vm.drives["rootfs"].applied? == true

      # Second configure and apply - add new resources
      vm =
        vm
        |> Firecracker.configure(:balloon, amount_mib: 128, deflate_on_oom: true)
        |> Firecracker.add(:drive, "data", path_on_host: "/tmp/data.ext4", is_root_device: false)
        |> Firecracker.apply()

      assert [] = vm.errors
      # Previously applied resources should still be applied
      assert vm.boot_source.applied? == true
      assert vm.drives["rootfs"].applied? == true
      # Newly configured resources should now be applied
      assert vm.balloon.applied? == true
      assert vm.drives["data"].applied? == true

      # Third apply without any new configuration should be a no-op
      vm = Firecracker.apply(vm)

      assert [] = vm.errors
      assert vm.boot_source.applied? == true
      assert vm.drives["rootfs"].applied? == true
      assert vm.balloon.applied? == true
      assert vm.drives["data"].applied? == true
    end

    test "reconfiguring a resource resets applied? flag and reapplies on next apply", %{vm: vm} do
      # Initial configuration and apply
      vm =
        vm
        |> Firecracker.configure(:machine_config, vcpu_count: 2, mem_size_mib: 512)
        |> Firecracker.apply()

      assert [] = vm.errors
      assert vm.machine_config.applied? == true

      machine_config = Firecracker.describe(vm, :machine_config)
      assert %{"vcpu_count" => 2, "mem_size_mib" => 512} = machine_config

      # Reconfigure the resource
      vm = Firecracker.configure(vm, :machine_config, vcpu_count: 4, mem_size_mib: 1024)

      # applied? flag should be reset
      assert vm.machine_config.applied? == false

      # Apply again
      vm = Firecracker.apply(vm)

      assert [] = vm.errors
      assert vm.machine_config.applied? == true

      machine_config = Firecracker.describe(vm, :machine_config)
      assert %{"vcpu_count" => 4, "mem_size_mib" => 1024} = machine_config
    end

    test "applies resources incrementally in multiple apply calls", %{
      vm: vm,
      kernel: kernel,
      rootfs: rootfs
    } do
      # First batch
      vm =
        vm
        |> Firecracker.configure(:boot_source, kernel_image_path: kernel)
        |> Firecracker.apply()

      assert vm.boot_source.applied? == true
      assert [] = vm.errors

      # Second batch
      vm =
        vm
        |> Firecracker.add(:drive, "rootfs",
          path_on_host: rootfs,
          is_root_device: true,
          is_read_only: false
        )
        |> Firecracker.apply()

      assert vm.boot_source.applied? == true
      assert vm.drives["rootfs"].applied? == true
      assert [] = vm.errors

      # Third batch
      vm =
        vm
        |> Firecracker.configure(:machine_config, vcpu_count: 2, mem_size_mib: 512)
        |> Firecracker.configure(:balloon, amount_mib: 100, deflate_on_oom: true)
        |> Firecracker.apply()

      assert vm.boot_source.applied? == true
      assert vm.drives["rootfs"].applied? == true
      assert vm.machine_config.applied? == true
      assert vm.balloon.applied? == true
      assert [] = vm.errors

      # Fourth batch - metadata
      vm =
        vm
        |> Firecracker.metadata("env", "test")
        |> Firecracker.apply()

      assert vm.boot_source.applied? == true
      assert vm.drives["rootfs"].applied? == true
      assert vm.machine_config.applied? == true
      assert vm.balloon.applied? == true
      assert vm.mmds.applied? == true
      assert [] = vm.errors

      # Verify all configurations are present
      boot_config = Firecracker.describe(vm, :boot_source)
      assert %{"kernel_image_path" => ^kernel} = boot_config

      machine_config = Firecracker.describe(vm, :machine_config)
      assert %{"vcpu_count" => 2, "mem_size_mib" => 512} = machine_config

      balloon_config = Firecracker.describe(vm, :balloon)
      assert %{"amount_mib" => 100} = balloon_config

      metadata = Firecracker.describe(vm, :mmds)
      assert %{"env" => "test"} = metadata
    end
  end

  describe "apply/1 post-boot" do
    @describetag :vm

    setup context do
      with :ok <- TestRequirements.check(context) do
        kernel = FirecrackerHelpers.fetch_kernel!()
        rootfs = FirecrackerHelpers.fetch_rootfs!()

        vm =
          Firecracker.new()
          |> Firecracker.configure(:boot_source, kernel_image_path: kernel)
          |> Firecracker.add(:drive, "rootfs",
            path_on_host: rootfs,
            is_root_device: true,
            is_read_only: false
          )
          |> Firecracker.configure(:balloon, amount_mib: 100, deflate_on_oom: true)
          |> Firecracker.start()
          |> Firecracker.boot()

        on_exit(fn -> Firecracker.stop(vm) end)

        [vm: vm]
      end
    end

    test "updates balloon stats_polling_interval_s after VM start", %{vm: vm} do
      assert %{"stats_polling_interval_s" => 0} = Firecracker.describe(vm, :balloon)

      updated_vm =
        vm
        |> Firecracker.configure(:balloon,
          stats_polling_interval_s: 5
        )
        |> Firecracker.apply()

      assert [] = updated_vm.errors

      assert %{"stats_polling_interval_s" => 5} = Firecracker.describe(updated_vm, :balloon)
    end

    test "updates balloon amount_mib after VM start", %{vm: vm} do
      updated_vm =
        vm
        |> Firecracker.configure(:balloon,
          amount_mib: 10
        )
        |> Firecracker.apply()

      assert [] = updated_vm.errors

      assert %{"amount_mib" => 10} = Firecracker.describe(updated_vm, :balloon)
    end

    test "updates both amount_mib and stats_polling_interval_s after VM start", %{vm: vm} do
      updated_vm =
        vm
        |> Firecracker.configure(:balloon,
          amount_mib: 5,
          stats_polling_interval_s: 10
        )
        |> Firecracker.apply()

      assert [] = updated_vm.errors

      assert %{"amount_mib" => 5, "stats_polling_interval_s" => 10} =
               Firecracker.describe(updated_vm, :balloon)
    end

    test "updates stats_polling_interval_s multiple times", %{vm: vm} do
      vm =
        vm
        |> Firecracker.configure(:balloon,
          amount_mib: 5,
          stats_polling_interval_s: 5
        )
        |> Firecracker.apply()

      config = Firecracker.describe(vm, :balloon)
      assert %{"stats_polling_interval_s" => 5} = config

      vm =
        vm
        |> Firecracker.configure(:balloon,
          amount_mib: 100,
          stats_polling_interval_s: 15
        )
        |> Firecracker.apply()

      config = Firecracker.describe(vm, :balloon)
      assert %{"stats_polling_interval_s" => 15} = config
    end

    test "updates machine_config after boot", %{vm: vm} do
      updated_vm =
        vm
        |> Firecracker.configure(:machine_config, vcpu_count: 4, mem_size_mib: 1024)
        |> Firecracker.apply()

      assert [] = updated_vm.errors
      assert updated_vm.machine_config.applied? == true

      assert %{"vcpu_count" => 4, "mem_size_mib" => 1024} =
               Firecracker.describe(updated_vm, :machine_config)
    end

    test "updates machine_config track_dirty_pages after boot", %{vm: vm} do
      updated_vm =
        vm
        |> Firecracker.configure(:machine_config, track_dirty_pages: true)
        |> Firecracker.apply()

      assert [] = updated_vm.errors
      assert updated_vm.machine_config.applied? == true

      assert %{"track_dirty_pages" => true} = Firecracker.describe(updated_vm, :machine_config)
    end

    test "updates mmds metadata after boot", %{vm: vm} do
      updated_vm =
        vm
        |> Firecracker.metadata("new_key", "new_value")
        |> Firecracker.apply()

      assert [] = updated_vm.errors
      assert updated_vm.mmds.applied? == true

      metadata = Firecracker.describe(updated_vm, :mmds)
      assert %{"new_key" => "new_value"} = metadata
    end

    test "replaces mmds metadata completely after boot", %{vm: vm} do
      # First set some initial metadata
      vm =
        vm
        |> Firecracker.metadata("initial", "data")
        |> Firecracker.apply()

      assert [] = vm.errors
      assert vm.mmds.applied? == true

      # Replace with completely new metadata
      updated_vm =
        vm
        |> Firecracker.metadata(%{"completely" => "new", "structure" => "here"})
        |> Firecracker.apply()

      assert [] = updated_vm.errors
      assert updated_vm.mmds.applied? == true

      metadata = Firecracker.describe(updated_vm, :mmds)
      assert %{"completely" => "new", "structure" => "here"} = metadata
      refute Map.has_key?(metadata, "initial")
    end

    test "updates drive path_on_host after boot", %{vm: vm} do
      rootfs = FirecrackerHelpers.fetch_rootfs!()

      updated_vm =
        vm
        |> Firecracker.add(:drive, "rootfs", path_on_host: rootfs)
        |> Firecracker.apply()

      assert [] = updated_vm.errors

      # Verify applied? flag is set
      assert updated_vm.drives["rootfs"].applied? == true
    end

    test "applies updates in paused state", %{vm: vm} do
      paused_vm = Firecracker.pause(vm)
      assert paused_vm.state == :paused

      updated_vm =
        paused_vm
        |> Firecracker.configure(:balloon, amount_mib: 5, stats_polling_interval_s: 7)
        |> Firecracker.apply()

      assert [] = updated_vm.errors

      assert %{"amount_mib" => 5, "stats_polling_interval_s" => 7} =
               Firecracker.describe(updated_vm, :balloon)

      assert updated_vm.balloon.applied? == true
    end

    test "does not re-apply already applied resources", %{vm: vm} do
      # The balloon is already applied from setup
      assert vm.balloon.applied? == true

      # Apply without changes should be no-op
      vm = Firecracker.apply(vm)

      assert [] = vm.errors
      assert vm.balloon.applied? == true

      assert %{"amount_mib" => 100} = Firecracker.describe(vm, :balloon)
    end

    test "resets applied? flag when resource is reconfigured", %{vm: vm} do
      assert vm.balloon.applied? == true

      # Reconfigure balloon
      vm = Firecracker.configure(vm, :balloon, amount_mib: 5)
      assert vm.balloon.applied? == false
      assert [] = vm.errors

      # Apply again
      vm = Firecracker.apply(vm)
      assert vm.balloon.applied? == true
      assert [] = vm.errors
      assert %{"amount_mib" => 5} = Firecracker.describe(vm, :balloon)
    end

    test "applies nested metadata structures after boot", %{vm: vm} do
      nested_metadata = %{
        "instance" => %{
          "id" => "i-1234567890",
          "type" => "m5.large",
          "region" => "us-west-2"
        },
        "user_data" => %{
          "script" => "#!/bin/bash\necho 'hello'",
          "config" => %{
            "enabled" => true,
            "settings" => %{
              "timeout" => 300,
              "retries" => 3
            }
          }
        },
        "tags" => ["web", "production", "v1.0.0"]
      }

      updated_vm =
        vm
        |> Firecracker.metadata(nested_metadata)
        |> Firecracker.apply()

      assert [] = updated_vm.errors
      assert updated_vm.mmds.applied? == true

      metadata = Firecracker.describe(updated_vm, :mmds)
      assert %{"instance" => %{"id" => "i-1234567890", "type" => "m5.large"}} = metadata
      assert %{"user_data" => %{"config" => %{"settings" => %{"timeout" => 300}}}} = metadata
      assert %{"tags" => ["web", "production", "v1.0.0"]} = metadata
    end

    test "chains configure/apply calls and only applies unapplied changes after boot", %{vm: vm} do
      # First configure and apply balloon
      vm =
        vm
        |> Firecracker.configure(:balloon, amount_mib: 50, stats_polling_interval_s: 3)
        |> Firecracker.apply()

      assert [] = vm.errors
      assert vm.balloon.applied? == true

      # Second configure and apply - update machine_config
      vm =
        vm
        |> Firecracker.configure(:machine_config, vcpu_count: 2, mem_size_mib: 256)
        |> Firecracker.apply()

      assert [] = vm.errors
      # Previously applied resources should still be applied
      assert vm.balloon.applied? == true
      # Newly configured resources should now be applied
      assert vm.machine_config.applied? == true

      # Third apply without any new configuration should be a no-op
      vm = Firecracker.apply(vm)

      assert [] = vm.errors
      assert vm.balloon.applied? == true
      assert vm.machine_config.applied? == true
    end

    test "applies resources incrementally in multiple apply calls after boot", %{vm: vm} do
      # First batch - update balloon
      vm =
        vm
        |> Firecracker.configure(:balloon, amount_mib: 75, stats_polling_interval_s: 2)
        |> Firecracker.apply()

      assert [] = vm.errors
      assert vm.balloon.applied? == true

      # Second batch - update machine_config
      vm =
        vm
        |> Firecracker.configure(:machine_config, vcpu_count: 2, mem_size_mib: 512)
        |> Firecracker.apply()

      assert [] = vm.errors
      assert vm.balloon.applied? == true
      assert vm.machine_config.applied? == true

      # Third batch - update metadata
      vm =
        vm
        |> Firecracker.metadata("env", "production")
        |> Firecracker.apply()

      assert [] = vm.errors
      assert vm.balloon.applied? == true
      assert vm.machine_config.applied? == true
      assert vm.mmds.applied? == true

      # Verify all configurations are present
      balloon_config = Firecracker.describe(vm, :balloon)
      assert %{"amount_mib" => 75, "stats_polling_interval_s" => 2} = balloon_config

      machine_config = Firecracker.describe(vm, :machine_config)
      assert %{"vcpu_count" => 2, "mem_size_mib" => 512} = machine_config

      metadata = Firecracker.describe(vm, :mmds)
      assert %{"env" => "production"} = metadata
    end

    test "updates multiple resources in one apply call after boot", %{vm: vm} do
      updated_vm =
        vm
        |> Firecracker.configure(:balloon, amount_mib: 200, stats_polling_interval_s: 8)
        |> Firecracker.configure(:machine_config, vcpu_count: 4, mem_size_mib: 2048)
        |> Firecracker.metadata("environment", "staging")
        |> Firecracker.apply()

      assert [] = updated_vm.errors

      # Verify all resources are marked as applied
      assert updated_vm.balloon.applied? == true
      assert updated_vm.machine_config.applied? == true
      assert updated_vm.mmds.applied? == true

      # Verify configurations via describe
      balloon_config = Firecracker.describe(updated_vm, :balloon)
      assert %{"amount_mib" => 200, "stats_polling_interval_s" => 8} = balloon_config

      machine_config = Firecracker.describe(updated_vm, :machine_config)
      assert %{"vcpu_count" => 4, "mem_size_mib" => 2048} = machine_config

      metadata = Firecracker.describe(updated_vm, :mmds)
      assert %{"environment" => "staging"} = metadata
    end

    test "raises when trying to modify boot_source after boot", %{vm: vm} do
      assert_raise NimbleOptions.ValidationError, ~r/unknown options/, fn ->
        vm
        |> Firecracker.configure(:boot_source, kernel_image_path: "/new/kernel")
      end
    end

    test "raises when trying to modify cpu_config after boot", %{vm: vm} do
      assert_raise NimbleOptions.ValidationError, ~r/unknown options/, fn ->
        vm
        |> Firecracker.configure(:cpu_config, kvm_capabilities: ["!56"])
      end
    end

    test "raises when trying to modify entropy after boot", %{vm: vm} do
      rate_limiter = Firecracker.RateLimiter.new()

      assert_raise NimbleOptions.ValidationError, ~r/unknown options/, fn ->
        vm
        |> Firecracker.configure(:entropy, rate_limiter: rate_limiter)
      end
    end

    test "raises when trying to modify logger after boot", %{vm: vm} do
      assert_raise NimbleOptions.ValidationError, ~r/unknown options/, fn ->
        vm
        |> Firecracker.configure(:logger, level: "Debug")
      end
    end

    test "raises when trying to modify metrics after boot", %{vm: vm} do
      assert_raise NimbleOptions.ValidationError, ~r/unknown options/, fn ->
        vm
        |> Firecracker.configure(:metrics, metrics_path: "/tmp/new_metrics.fifo")
      end
    end

    test "raises when trying to modify serial after boot", %{vm: vm} do
      assert_raise NimbleOptions.ValidationError, ~r/unknown options/, fn ->
        vm
        |> Firecracker.configure(:serial, output_path: "/tmp/new_serial.log")
      end
    end

    test "raises when trying to modify vsock after boot", %{vm: vm} do
      assert_raise NimbleOptions.ValidationError, ~r/unknown options/, fn ->
        vm
        |> Firecracker.configure(:vsock, guest_cid: 5, uds_path: "/tmp/new.sock")
      end
    end

    test "raises when trying to modify non-updatable drive fields after boot", %{vm: vm} do
      assert_raise NimbleOptions.ValidationError, ~r/unknown options.*is_root_device/, fn ->
        vm
        |> Firecracker.add(:drive, "rootfs", is_root_device: false)
      end
    end

    @tag tap: "tap0"
    test "raises when trying to modify network_interface non-updatable fields after boot", %{
      vm: vm
    } do
      vm =
        vm
        |> Firecracker.add(:network_interface, "eth0",
          host_dev_name: "tap0",
          guest_mac: "AA:FC:00:00:00:01"
        )
        |> Firecracker.apply()

      # Stop, boot, and test post-boot
      Firecracker.stop(vm)

      kernel = FirecrackerHelpers.fetch_kernel!()
      rootfs = FirecrackerHelpers.fetch_rootfs!()

      vm =
        Firecracker.new()
        |> Firecracker.configure(:boot_source, kernel_image_path: kernel)
        |> Firecracker.add(:drive, "rootfs",
          path_on_host: rootfs,
          is_root_device: true,
          is_read_only: false
        )
        |> Firecracker.add(:network_interface, "eth0",
          host_dev_name: "tap0",
          guest_mac: "AA:FC:00:00:00:01"
        )
        |> Firecracker.start()
        |> Firecracker.boot()

      on_exit(fn -> Firecracker.stop(vm) end)

      assert_raise NimbleOptions.ValidationError, ~r/unknown options/, fn ->
        vm
        |> Firecracker.add(:network_interface, "eth0", host_dev_name: "tap1")
      end
    end
  end

  describe "describe/1" do
    @describetag :vm

    setup context do
      with :ok <- TestRequirements.check(context) do
        :ok
      end
    end

    test "describes a started VM" do
      vm = Firecracker.new() |> Firecracker.start()
      on_exit(fn -> Firecracker.stop(vm) end)

      %{"id" => "anonymous-instance" <> _, "state" => "Not started"} = Firecracker.describe(vm)
    end

    test "raises when attempting to describe a VM that's not running" do
      assert_raise ArgumentError, ~r/unable to describe VM/, fn ->
        Firecracker.new() |> Firecracker.describe()
      end
    end
  end

  describe "describe/2" do
    @describetag :vm

    test "describes a started VMs machine configuration" do
      vm = Firecracker.new() |> Firecracker.start()
      on_exit(fn -> Firecracker.stop(vm) end)

      assert %{
               "huge_pages" => "None",
               "mem_size_mib" => 128,
               "smt" => false,
               "track_dirty_pages" => false,
               "vcpu_count" => 1
             } = Firecracker.describe(vm, :machine_config)
    end

    test "describes a started VMs mmds" do
      vm =
        Firecracker.new()
        |> Firecracker.metadata("owner", "sean")
        |> Firecracker.start()

      on_exit(fn -> Firecracker.stop(vm) end)

      assert %{"owner" => "sean"} = Firecracker.describe(vm, :mmds)
    end

    test "describes a started VMs configuration" do
      vm = Firecracker.new() |> Firecracker.start()
      on_exit(fn -> Firecracker.stop(vm) end)

      assert %{} = Firecracker.describe(vm, :vm_config)
    end

    test "raises if VM is not started" do
      assert_raise ArgumentError, ~r/unable to describe/, fn ->
        Firecracker.new() |> Firecracker.describe()
      end
    end
  end

  describe "boot/1" do
    @describetag :vm

    setup context do
      with :ok <- TestRequirements.check(context) do
        kernel = FirecrackerHelpers.fetch_kernel!()
        rootfs = FirecrackerHelpers.fetch_rootfs!()

        vm =
          Firecracker.new()
          |> Firecracker.configure(:boot_source, kernel_image_path: kernel)
          |> Firecracker.add(:drive, "rootfs",
            path_on_host: rootfs,
            is_root_device: true,
            is_read_only: false
          )
          |> Firecracker.start()

        on_exit(fn -> Firecracker.stop(vm) end)

        [vm: vm]
      end
    end

    test "boots a vm", %{vm: vm} do
      assert %Firecracker{state: :running} = Firecracker.boot(vm)
      assert %{"id" => "anonymous-instance" <> _, "state" => "Running"} = Firecracker.describe(vm)
    end

    test "raises when trying to boot a vm that's not started" do
      assert_raise ArgumentError, ~r/unable to boot/, fn ->
        Firecracker.new() |> Firecracker.boot()
      end
    end
  end

  describe "pause/1" do
    @describetag :vm

    setup context do
      with :ok <- TestRequirements.check(context) do
        kernel = FirecrackerHelpers.fetch_kernel!()
        rootfs = FirecrackerHelpers.fetch_rootfs!()

        vm =
          Firecracker.new()
          |> Firecracker.configure(:boot_source, kernel_image_path: kernel)
          |> Firecracker.add(:drive, "rootfs",
            path_on_host: rootfs,
            is_root_device: true,
            is_read_only: false
          )
          |> Firecracker.start()
          |> Firecracker.boot()

        on_exit(fn -> Firecracker.stop(vm) end)

        [vm: vm]
      end
    end

    test "pauses a running vm", %{vm: vm} do
      vm = Firecracker.pause(vm)

      assert %Firecracker{state: :paused} = vm
      assert %{"state" => "Paused"} = Firecracker.describe(vm)
    end

    test "is a no-op if the VM is already paused", %{vm: vm} do
      vm = Firecracker.pause(vm)

      assert %Firecracker{state: :paused} = vm
      assert %{"state" => "Paused"} = Firecracker.describe(vm)
      assert %Firecracker{state: :paused} = Firecracker.pause(vm)
      assert %{"state" => "Paused"} = Firecracker.describe(vm)
    end

    test "raises if the VM is not in a booted state" do
      assert_raise ArgumentError, ~r/unable to pause/, fn ->
        Firecracker.new() |> Firecracker.pause()
      end
    end
  end

  describe "resume/1" do
    @describetag :vm

    setup context do
      with :ok <- TestRequirements.check(context) do
        kernel = FirecrackerHelpers.fetch_kernel!()
        rootfs = FirecrackerHelpers.fetch_rootfs!()

        vm =
          Firecracker.new()
          |> Firecracker.configure(:boot_source, kernel_image_path: kernel)
          |> Firecracker.add(:drive, "rootfs",
            path_on_host: rootfs,
            is_root_device: true,
            is_read_only: false
          )
          |> Firecracker.start()
          |> Firecracker.boot()

        on_exit(fn -> Firecracker.stop(vm) end)

        [vm: vm]
      end
    end

    test "resumes a paused vm", %{vm: vm} do
      vm = Firecracker.pause(vm)

      assert %{"state" => "Paused"} = Firecracker.describe(vm)
      assert vm = %Firecracker{state: :running} = Firecracker.resume(vm)
      assert %{"state" => "Running"} = Firecracker.describe(vm)
    end

    test "is a no-op if the VM is already running", %{vm: vm} do
      assert %{"state" => "Running"} = Firecracker.describe(vm)
      assert vm = %Firecracker{state: :running} = Firecracker.resume(vm)
      assert %{"state" => "Running"} = Firecracker.describe(vm)
    end

    test "raises if the VM is not started" do
      assert_raise ArgumentError, ~r/unable to resume VM/, fn ->
        Firecracker.new() |> Firecracker.resume()
      end
    end
  end

  describe "shutdown/1" do
    @describetag :vm

    setup context do
      with :ok <- TestRequirements.check(context) do
        kernel = FirecrackerHelpers.fetch_kernel!()
        rootfs = FirecrackerHelpers.fetch_rootfs!()

        vm =
          Firecracker.new()
          |> Firecracker.configure(:boot_source, kernel_image_path: kernel)
          |> Firecracker.add(:drive, "rootfs",
            path_on_host: rootfs,
            is_root_device: true,
            is_read_only: false
          )
          |> Firecracker.start()
          |> Firecracker.boot()

        on_exit(fn -> Firecracker.stop(vm) end)

        [vm: vm]
      end
    end

    test "shutsdown a running vm", %{vm: vm} do
      vm = Firecracker.shutdown(vm)

      assert %Firecracker{state: :shutdown} = vm
    end

    test "is a no-op if the VM is already shutdown", %{vm: vm} do
      vm = Firecracker.shutdown(vm)

      assert %Firecracker{state: :shutdown} = vm
      assert %Firecracker{state: :shutdown} = Firecracker.shutdown(vm)
    end

    test "raises if the VM is not started" do
      assert_raise ArgumentError, ~r/unable to shutdown VM/, fn ->
        Firecracker.new() |> Firecracker.shutdown()
      end
    end
  end

  describe "stop/1" do
    @describetag :vm

    setup context do
      with :ok <- TestRequirements.check(context) do
        kernel = FirecrackerHelpers.fetch_kernel!()
        rootfs = FirecrackerHelpers.fetch_rootfs!()

        vm =
          Firecracker.new()
          |> Firecracker.configure(:boot_source, kernel_image_path: kernel)
          |> Firecracker.add(:drive, "rootfs",
            path_on_host: rootfs,
            is_root_device: true,
            is_read_only: false
          )
          |> Firecracker.start()

        # Stopping a VM that's already stopped is a no-op anyway, so this is fine
        on_exit(fn -> Firecracker.stop(vm) end)

        [vm: vm]
      end
    end

    test "stops a vm", %{vm: vm} do
      assert %Firecracker{state: :exited} = Firecracker.stop(vm)
    end

    test "kills the OS process", %{vm: vm} do
      assert %Firecracker{process: %Px{pid: pid, status: {:exited, 143}}} =
               Firecracker.stop(vm)

      assert {_, 1} = System.cmd("ps", ["-p", "#{pid}"])
    end

    test "cleans up created api socket", %{vm: vm} do
      assert %Firecracker{api_sock: sock} = Firecracker.stop(vm)
      refute File.exists?(sock)
    end

    test "cleans up created vsock if exists" do
      vm =
        Firecracker.new()
        |> Firecracker.configure(:vsock, guest_cid: 3, uds_path: "/tmp/vsock.sock")
        |> Firecracker.start()

      assert %Firecracker{state: :exited} = Firecracker.stop(vm)
      refute File.exists?("/tmp/vsock.sock")
    end
  end

  describe "version/1" do
    @describetag :vm

    test "returns the binary version for a vm using default path" do
      version =
        Firecracker.new()
        |> Firecracker.version()

      assert version =~ ~r"v\d\.\d+\.\d"
    end

    test "returns the binary version for a vm using a custom path" do
      version =
        Firecracker.new()
        |> Firecracker.set_option(:firecracker_path, "/usr/bin/firecracker")
        |> Firecracker.version()

      assert version =~ ~r"v\d\.\d+\.\d"
    end

    test "returns the binary version using environment path when struct path is nil" do
      original_env = Application.get_env(:firecracker, Firecracker, [])

      try do
        Application.put_env(:firecracker, Firecracker, firecracker_path: "/usr/bin/firecracker")

        version =
          Firecracker.new()
          |> Firecracker.version()

        assert version =~ ~r"v\d\.\d+\.\d"
      after
        Application.put_env(:firecracker, Firecracker, original_env)
      end
    end

    test "prefers struct path over environment path" do
      original_env = Application.get_env(:firecracker, Firecracker, [])

      try do
        Application.put_env(:firecracker, Firecracker, firecracker_path: "/usr/bin/firecracker")

        version =
          Firecracker.new()
          |> Firecracker.set_option(:firecracker_path, "/usr/bin/firecracker")
          |> Firecracker.version()

        assert version =~ ~r"v\d\.\d+\.\d"
      after
        Application.put_env(:firecracker, Firecracker, original_env)
      end
    end
  end

  describe "version/0" do
    @describetag :vm

    test "returns the binary version for the environment using default path" do
      version = Firecracker.version()

      assert version =~ ~r"v\d\.\d+\.\d"
    end

    test "returns the binary version using custom path from application env" do
      original_env = Application.get_env(:firecracker, Firecracker, [])

      try do
        Application.put_env(:firecracker, Firecracker, firecracker_path: "/usr/bin/firecracker")

        version = Firecracker.version()

        assert version =~ ~r"v\d\.\d+\.\d"
      after
        Application.put_env(:firecracker, Firecracker, original_env)
      end
    end
  end

  describe "snapshot_version/1" do
    @describetag :vm

    test "returns the binary snapshot version for a vm using default path" do
      version =
        Firecracker.new()
        |> Firecracker.snapshot_version()

      assert version =~ ~r/^v\d+\.\d+\.\d+/
    end

    test "returns the binary snapshot version for a vm using a custom path" do
      version =
        Firecracker.new()
        |> Firecracker.set_option(:firecracker_path, "/usr/bin/firecracker")
        |> Firecracker.snapshot_version()

      assert version =~ ~r/^v\d+\.\d+\.\d+/
    end

    test "returns the binary snapshot version using environment path when struct path is nil" do
      original_env = Application.get_env(:firecracker, Firecracker, [])

      try do
        Application.put_env(:firecracker, Firecracker, firecracker_path: "/usr/bin/firecracker")

        version =
          Firecracker.new()
          |> Firecracker.snapshot_version()

        assert version =~ ~r/^v\d+\.\d+\.\d+/
      after
        Application.put_env(:firecracker, Firecracker, original_env)
      end
    end

    test "prefers struct path over environment path" do
      original_env = Application.get_env(:firecracker, Firecracker, [])

      try do
        Application.put_env(:firecracker, Firecracker, firecracker_path: "/usr/bin/firecracker")

        version =
          Firecracker.new()
          |> Firecracker.set_option(:firecracker_path, "/usr/bin/firecracker")
          |> Firecracker.snapshot_version()

        assert version =~ ~r/^v\d+\.\d+\.\d+/
      after
        Application.put_env(:firecracker, Firecracker, original_env)
      end
    end
  end

  describe "snapshot_version/0" do
    @describetag :vm

    test "returns the binary version for the environment using default path" do
      version = Firecracker.snapshot_version()

      assert version =~ ~r/^v\d+\.\d+\.\d+/
    end

    test "returns the binary snapshot version using custom path from application env" do
      original_env = Application.get_env(:firecracker, Firecracker, [])

      try do
        Application.put_env(:firecracker, Firecracker, firecracker_path: "/usr/bin/firecracker")

        version = Firecracker.snapshot_version()

        assert version =~ ~r/^v\d+\.\d+\.\d+/
      after
        Application.put_env(:firecracker, Firecracker, original_env)
      end
    end
  end

  describe "Inspect implementation" do
    test "displays id, state, api_sock, and pid for basic VM" do
      vm = Firecracker.new(id: "test-vm", api_sock: "/tmp/test.sock")
      output = inspect(vm)

      assert output =~ "#Firecracker<"
      assert output =~ "id: \"test-vm\""
      assert output =~ "state: :initial"
      assert output =~ "api_sock: \"/tmp/test.sock\""
      assert output =~ "pid: nil"
      refute output =~ "jailed:"
      refute output =~ "errors:"
    end

    test "displays jailed: true when jailer is configured" do
      vm =
        Firecracker.new(id: "jailed-vm", api_sock: "/tmp/jailed.sock")
        |> Firecracker.jail(uid: 1000, gid: 1000)

      output = inspect(vm)

      assert output =~ "jailed: true"
    end

    test "does not display jailed field when jailer is not configured" do
      vm = Firecracker.new(id: "not-jailed", api_sock: "/tmp/test.sock")
      output = inspect(vm)

      refute output =~ "jailed:"
    end

    test "displays error count when errors are present" do
      vm = Firecracker.new(id: "error-vm", api_sock: "/tmp/test.sock")
      vm_with_errors = %{vm | errors: [{:drive, "error1"}, {:network, "error2"}]}
      output = inspect(vm_with_errors)

      assert output =~ "errors: 2"
    end

    test "does not display errors field when no errors present" do
      vm = Firecracker.new(id: "no-errors", api_sock: "/tmp/test.sock")
      output = inspect(vm)

      refute output =~ "errors:"
    end

    test "displays pid when process is set" do
      vm = Firecracker.new(id: "with-pid", api_sock: "/tmp/test.sock")
      vm_with_process = %{vm | process: %Px{pid: 12345}}
      output = inspect(vm_with_process)

      assert output =~ "pid: 12345"
    end
  end
end
