defmodule TempFiles do
  @doc """
  Helper for working with TempFiles in tests.
  """

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

defmodule TestRequirements do
  @feature_versions %{
    serial: "1.13.0",
    pmem: "1.14.0"
  }

  def check(context) do
    with :ok <- check_tap(context),
         :ok <- check_feature(context) do
      :ok
    end
  end

  defp check_tap(%{tap: tap}) when is_binary(tap) do
    if tap_exists?(tap) do
      :ok
    else
      msg =
        "tap device '#{tap}' not found. Create with: sudo ip tuntap add dev #{tap} mode tap && sudo ip link set #{tap} up"

      IO.warn(msg)
      {:ok, skip: msg}
    end
  end

  defp check_tap(%{tap: taps}) when is_list(taps) do
    missing = Enum.reject(taps, &tap_exists?/1)

    if missing == [] do
      :ok
    else
      cmds =
        Enum.map_join(missing, " && ", fn tap ->
          "sudo ip tuntap add dev #{tap} mode tap && sudo ip link set #{tap} up"
        end)

      msg = "tap device(s) #{inspect(missing)} not found. Create with: #{cmds}"
      IO.warn(msg)
      {:ok, skip: msg}
    end
  end

  defp check_tap(_context), do: :ok

  defp tap_exists?(name) do
    File.exists?("/sys/class/net/#{name}")
  end

  defp check_feature(%{feature: feature}) when is_atom(feature) do
    if feature_supported?(feature) do
      :ok
    else
      installed = installed_version() || "not found"
      required = @feature_versions[feature]

      msg =
        "feature '#{feature}' requires Firecracker >= #{required}, but #{installed} is installed"

      IO.warn(msg)
      {:ok, skip: msg}
    end
  end

  defp check_feature(%{feature: features}) when is_list(features) do
    unsupported = Enum.reject(features, &feature_supported?/1)

    if unsupported == [] do
      :ok
    else
      installed = installed_version() || "not found"

      missing =
        Enum.map_join(unsupported, ", ", fn f ->
          "#{f} (>= #{@feature_versions[f]})"
        end)

      msg = "features #{missing} not supported by Firecracker #{installed}"
      IO.warn(msg)
      {:ok, skip: msg}
    end
  end

  defp check_feature(_context), do: :ok

  defp feature_supported?(feature) when is_atom(feature) do
    case installed_version() do
      nil -> false
      installed -> Version.compare(installed, min_version(feature)) in [:gt, :eq]
    end
  end

  defp min_version(feature) do
    case Map.fetch(@feature_versions, feature) do
      {:ok, version} -> Version.parse!(version)
      :error -> raise "Unknown feature: #{feature}"
    end
  end

  def installed_version do
    case :persistent_term.get({__MODULE__, :version}, :not_cached) do
      :not_cached ->
        version = fetch_version()
        :persistent_term.put({__MODULE__, :version}, version)
        version

      version ->
        version
    end
  end

  defp fetch_version do
    case Firecracker.which() do
      nil ->
        nil

      path ->
        {output, 0} = System.cmd(path, ["--version"])

        output
        |> String.split("\n")
        |> hd()
        |> String.trim()
        |> String.replace_leading("Firecracker v", "")
        |> Version.parse!()
    end
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
