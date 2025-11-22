defmodule Firecracker.SnapshotTest do
  use ExUnit.Case, async: true

  alias Firecracker.Snapshot
  alias Firecracker.Snapshot.MemoryBackend

  describe "new/1" do
    test "creates a snapshot with required path and type" do
      snapshot = Snapshot.new(path: "/test/path.json", type: :full)

      assert %Snapshot{
               snapshot_path: "/test/path.json",
               snapshot_type: :full,
               mem_file_path: nil,
               memory_backend: nil,
               resume_vm: true,
               track_dirty_pages: true,
               network_overrides: %{}
             } = snapshot
    end

    test "creates a snapshot with optional mem_file_path" do
      snapshot =
        Snapshot.new(
          path: "/test/path.json",
          type: :diff,
          mem_file_path: "/test/memory.mem"
        )

      assert snapshot.mem_file_path == "/test/memory.mem"
    end

    test "creates a snapshot with custom resume_vm option" do
      snapshot =
        Snapshot.new(
          path: "/test/path.json",
          type: :full,
          resume_vm: false
        )

      assert snapshot.resume_vm == false
    end

    test "raises error when path is missing" do
      assert_raise ArgumentError, ":path is required", fn ->
        Snapshot.new(type: :full)
      end
    end

    test "raises error when type is missing" do
      assert_raise ArgumentError, ":type is required", fn ->
        Snapshot.new(path: "/test/path.json")
      end
    end

    test "raises error when invalid options are provided" do
      assert_raise ArgumentError, fn ->
        Snapshot.new(path: "/test/path.json", type: :full, invalid_option: true)
      end
    end
  end

  describe "set_options/2" do
    test "updates snapshot path" do
      snapshot = Snapshot.new(path: "/old/path.json", type: :full)
      updated = Snapshot.set_options(snapshot, path: "/new/path.json")

      assert updated.snapshot_path == "/new/path.json"
    end

    test "updates snapshot type" do
      snapshot = Snapshot.new(path: "/test/path.json", type: :full)
      updated = Snapshot.set_options(snapshot, type: :diff)

      assert updated.snapshot_type == :diff
    end

    test "updates resume_vm option" do
      snapshot = Snapshot.new(path: "/test/path.json", type: :full)
      updated = Snapshot.set_options(snapshot, resume_vm: false)

      assert updated.resume_vm == false
    end

    test "updates mem_file_path" do
      snapshot = Snapshot.new(path: "/test/path.json", type: :full)
      updated = Snapshot.set_options(snapshot, mem_file_path: "/new/memory.mem")

      assert updated.mem_file_path == "/new/memory.mem"
    end

    test "does not update options with nil values" do
      snapshot = Snapshot.new(path: "/test/path.json", type: :full, mem_file_path: "/memory.mem")
      updated = Snapshot.set_options(snapshot, mem_file_path: nil)

      assert updated.mem_file_path == "/memory.mem"
    end

    test "raises error when invalid options are provided" do
      snapshot = Snapshot.new(path: "/test/path.json", type: :full)

      assert_raise ArgumentError, fn ->
        Snapshot.set_options(snapshot, invalid_option: true)
      end
    end
  end

  describe "memory_backend/2" do
    test "creates File backend and removes mem_file_path" do
      snapshot = Snapshot.new(path: "/test/path.json", type: :full, mem_file_path: "/memory.mem")

      updated =
        Snapshot.memory_backend(snapshot,
          backend_type: "File",
          backend_path: "/backend/memory.mem"
        )

      assert %MemoryBackend{
               backend_type: "File",
               backend_path: "/backend/memory.mem"
             } = updated.memory_backend

      assert updated.mem_file_path == nil
    end

    test "creates Uffd backend" do
      snapshot = Snapshot.new(path: "/test/path.json", type: :full)

      updated =
        Snapshot.memory_backend(snapshot,
          backend_type: "Uffd",
          backend_path: "/uds/socket"
        )

      assert %MemoryBackend{
               backend_type: "Uffd",
               backend_path: "/uds/socket"
             } = updated.memory_backend
    end

    test "raises error when backend_type is missing" do
      snapshot = Snapshot.new(path: "/test/path.json", type: :full)

      assert_raise RuntimeError, "backend_type is required", fn ->
        Snapshot.memory_backend(snapshot, backend_path: "/backend/path")
      end
    end

    test "raises error when backend_path is missing" do
      snapshot = Snapshot.new(path: "/test/path.json", type: :full)

      assert_raise RuntimeError, "backend_path is required", fn ->
        Snapshot.memory_backend(snapshot, backend_type: "File")
      end
    end

    test "raises error when invalid options are provided" do
      snapshot = Snapshot.new(path: "/test/path.json", type: :full)

      assert_raise ArgumentError, fn ->
        Snapshot.memory_backend(snapshot,
          backend_type: "File",
          backend_path: "/path",
          invalid_option: true
        )
      end
    end
  end

  describe "network_override/3" do
    test "adds network override to empty map" do
      snapshot = Snapshot.new(path: "/test/path.json", type: :full)
      updated = Snapshot.network_override(snapshot, "eth0", "tap0")

      assert updated.network_overrides == %{"eth0" => "tap0"}
    end

    test "adds multiple network overrides" do
      snapshot = Snapshot.new(path: "/test/path.json", type: :full)

      updated =
        snapshot
        |> Snapshot.network_override("eth0", "tap0")
        |> Snapshot.network_override("eth1", "tap1")

      assert updated.network_overrides == %{
               "eth0" => "tap0",
               "eth1" => "tap1"
             }
    end

    test "overwrites existing network override" do
      snapshot = Snapshot.new(path: "/test/path.json", type: :full)

      updated =
        snapshot
        |> Snapshot.network_override("eth0", "tap0")
        |> Snapshot.network_override("eth0", "tap2")

      assert updated.network_overrides == %{"eth0" => "tap2"}
    end
  end
end
