defmodule TempFiles do
  use GenServer

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def path(prefix, suffix \\ "") do
    path =
      Path.join([System.tmp_dir(), "#{prefix}-#{System.unique_integer([:positive])}#{suffix}"])

    register(path)
    path
  end

  def register(path, pid \\ self()) do
    GenServer.call(__MODULE__, {:register, pid, path})
    path
  end

  def cleanup(pid \\ self()) do
    paths = GenServer.call(__MODULE__, {:cleanup, pid})
    Enum.each(paths, &File.rm_rf/1)
    :ok
  end

  @impl true
  def init(state), do: {:ok, state}

  @impl true
  def handle_call({:register, pid, path}, _from, state) do
    {:reply, :ok, Map.update(state, pid, [path], &[path | &1])}
  end

  def handle_call({:cleanup, pid}, _from, state) do
    {paths, state} = Map.pop(state, pid, [])
    {:reply, paths, state}
  end

  @impl true
  def terminate(_reason, state) do
    state
    |> Map.values()
    |> List.flatten()
    |> Enum.each(&File.rm_rf/1)
  end

  def write!(prefix, suffix, content) do
    path = path(prefix, suffix)
    File.write!(path, content)
    path
  end

  def touch!(prefix, suffix \\ "") do
    path = path(prefix, suffix)
    File.touch!(path)
    path
  end

  def mkdir_p!(prefix) do
    path = path(prefix)
    File.mkdir_p!(path)
    path
  end

  def mkfifo!(prefix, suffix \\ ".fifo") do
    path = path(prefix, suffix)
    {_, 0} = System.cmd("mkfifo", [path])
    path
  end
end

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
