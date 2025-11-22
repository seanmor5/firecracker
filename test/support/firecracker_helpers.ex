defmodule FirecrackerHelpers do
  require Logger

  @kernel_url "https://s3.amazonaws.com/spec.ccfc.min/firecracker-ci/ftrace/x86_64/vmlinux-6.1.102"
  @rootfs_url "https://cloud-images.ubuntu.com/wsl/releases/24.04/current/ubuntu-noble-wsl-amd64-24.04lts.rootfs.tar.gz"
  @test_cache "test/cache"

  def fetch_kernel!() do
    :ok = File.mkdir_p(@test_cache)

    kernel_path = Path.join(@test_cache, "vmlinux")

    if File.exists?(kernel_path) do
      kernel_path
    else
      %{body: body} = Req.get!(@kernel_url)
      File.write!(kernel_path, body)
      kernel_path
    end
  end

  def fetch_rootfs!() do
    :ok = File.mkdir_p(@test_cache)

    rootfs_ext4_path = Path.join(@test_cache, "ubuntu-24.04.ext4")
    rootfs_tarball_path = Path.join(@test_cache, "ubuntu-24.04.rootfs.tar.gz")
    rootfs_extracted_path = Path.join(@test_cache, "ubuntu-24.04-rootfs")

    if File.exists?(rootfs_ext4_path) do
      rootfs_ext4_path
    else
      unless File.exists?(rootfs_tarball_path) do
        Logger.debug("Downloading Ubuntu 24.04 rootfs...")
        %{body: body} = Req.get!(@rootfs_url, raw: true)
        File.write!(rootfs_tarball_path, body)
        Logger.debug("Ubuntu 24.04 download complete")
      end

      unless File.exists?(rootfs_extracted_path) do
        :ok = File.mkdir_p(rootfs_extracted_path)

        {_output, 0} =
          System.cmd("tar", [
            "-xzf",
            rootfs_tarball_path,
            "-C",
            rootfs_extracted_path
          ])
      end

      Logger.debug("Creating ext4 filesystem image...")

      {_output, 0} =
        System.cmd("dd", [
          "if=/dev/zero",
          "of=#{rootfs_ext4_path}",
          "bs=1M",
          "count=0",
          "seek=2048"
        ])

      {_output, 0} = System.cmd("mkfs.ext4", ["-F", rootfs_ext4_path])

      mount_point = Path.join(@test_cache, "mnt")
      :ok = File.mkdir_p(mount_point)

      {_output, 0} = System.cmd("sudo", ["mount", rootfs_ext4_path, mount_point])

      try do
        {_output, 0} =
          System.cmd("sudo", [
            "cp",
            "-a",
            "#{rootfs_extracted_path}/.",
            mount_point
          ])
      after
        {_output, 0} = System.cmd("sudo", ["umount", mount_point])
      end

      Logger.debug("ext4 filesystem image created successfully")

      rootfs_ext4_path
    end
  end
end
