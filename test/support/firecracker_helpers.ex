defmodule FirecrackerHelpers do
  @kernel_url "https://s3.amazonaws.com/spec.ccfc.min/firecracker-ci/ftrace/x86_64/vmlinux-6.1.102"
  @rootfs_url "https://github.com/seanmor5/firecracker/releases/download/rootfs-ubuntu-24.04/ubuntu-24.04.ext4.gz"
  @test_cache "test/cache"

  def fetch_kernel!() do
    fetch!("vmlinux", @kernel_url)
  end

  def fetch_rootfs!() do
    fetch!("ubuntu-24.04.ext4", @rootfs_url)
  end

  defp fetch!(filename, url) do
    :ok = File.mkdir_p(@test_cache)
    path = Path.join(@test_cache, filename)

    if File.exists?(path) do
      path
    else
      %{body: body} = Req.get!(url)
      File.write!(path, body)
      path
    end
  end
end
