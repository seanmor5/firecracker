defmodule Mix.Tasks.Firecracker.Install do
  @moduledoc """
  Downloads the Firecracker binary to a specified location.

  This will install the following binaries:

    * `firecracker` - the firecracker binary
    * `jailer` - the firecracker jailer
    * `seccompiler` - a seccomp compiler
    * `snapshot-editor` - firecracker snapshot editor
    * `rebase-snap` - firecracker rebase snapshot
    * `cpu-template-helper` - firecracker template helper

  ## Usage

      mix firecracker.install [options]

  ## Options

    * `--version` - Firecracker version to download (default: 1.11)
    * `--path` - Installation path (default: $HOME/.firecracker/bin)
    * `--force` - Overwrite existing binary if it exists
    * `--architecture` - Firecracker architecture to download. Defaults
      to the system architecture
  """
  use Mix.Task

  @shortdoc "Download Firecracker binary"

  @default_version "1.13.0"
  @base_url "https://github.com/firecracker-microvm/firecracker/releases/download"
  @binaries [
    "cpu-template-helper",
    "firecracker",
    "jailer",
    "rebase-snap",
    "seccompiler-bin",
    "snapshot-editor"
  ]

  @requirements ["app.start"]

  def run(argv) do
    opts = parse_args(argv, [])

    version = Keyword.get(opts, :version, @default_version)
    install_path = Keyword.get(opts, :path) || default_install_path()
    arch = Keyword.get(opts, :arch) || get_architecture()
    force? = Keyword.get(opts, :force, false)

    download_firecracker(version, arch, install_path, force?)
  end

  defp parse_args([], opts), do: opts

  defp parse_args(["--force" | args], opts) do
    parse_args(args, Keyword.put(opts, :force, true))
  end

  defp parse_args(["--version", version | args], opts) do
    parse_args(args, Keyword.put(opts, :verison, version))
  end

  defp parse_args(["--architecture", arch | args], opts) do
    parse_args(args, Keyword.put(opts, :architecture, arch))
  end

  defp parse_args(["--path", path | args], opts) do
    parse_args(args, Keyword.put(opts, :path, path))
  end

  defp download_firecracker(version, arch, install_path, force?) do
    if not force? and Enum.all?(@binaries, &File.exists?(Path.join(install_path, &1))) do
      Mix.shell().info("Firecracker binaries already exist at #{install_path}")
      Mix.shell().info("Use --force to overwrite")
    else
      Mix.shell().info("Downloading Firecracker v#{version} for #{arch}...")

      File.mkdir_p!(install_path)

      with {:ok, firecracker_url} <- get_download_url(version, "firecracker", arch),
           :ok <- download_binary(firecracker_url, install_path, arch, version) do
        Mix.shell().info([
          :green,
          "Successfully installed Firecracker binaries to #{install_path}",
          :reset
        ])

        Mix.shell().info("\nNext steps:")
        Mix.shell().info("1. Add #{install_path} to your PATH")
        Mix.shell().info("2. Run 'firecracker --version' to verify installation")
      else
        error ->
          Mix.shell().error("Failed to download Firecracker: #{inspect(error)}")
          System.halt(1)
      end
    end
  end

  defp default_install_path do
    home = System.get_env("HOME") || "."
    Path.join([home, ".firecracker", "bin"])
  end

  defp get_architecture do
    case :erlang.system_info(:system_architecture) |> to_string() do
      "x86_64" <> _ ->
        "x86_64"

      "aarch64" <> _ ->
        "aarch64"

      arch ->
        Mix.shell().error("Unsupported architecture: #{arch}")
        System.halt(1)
    end
  end

  defp get_download_url(version, binary_name, arch) do
    filename = "#{binary_name}-v#{version}-#{arch}"
    url = "#{@base_url}/v#{version}/#{filename}.tgz"
    {:ok, url}
  end

  defp download_binary(url, destination, arch, version) do
    temp_file = Path.join(System.tmp_dir!(), "download.tgz")
    Mix.shell().info("Downloading from #{url} to #{destination}...")

    try do
      case Req.get(url, into: File.stream!(temp_file)) do
        {:ok, %Req.Response{status: 200}} ->
          case :erl_tar.extract(temp_file, [:memory, :compressed]) do
            {:ok, files} ->
              Enum.each(@binaries, fn binary_name ->
                full_name = "#{binary_name}-v#{version}-#{arch}"
                install_path = Path.join(destination, binary_name)

                {path, binary} =
                  Enum.find(files, fn {tarname, _} ->
                    tarname
                    |> List.to_string()
                    |> Path.basename()
                    |> Kernel.==(full_name)
                  end)

                IO.inspect(install_path)

                Mix.shell().info("Installing #{List.to_string(path)} to #{install_path}")
                File.write!(install_path, binary)
                make_executable(install_path)
              end)

            error ->
              error
          end

        {:ok, %Req.Response{status: status}} ->
          {:error, "HTTP #{status}"}

        {:error, error} ->
          {:error, "Download failed: #{inspect(error)}"}
      end
    after
      File.rm(temp_file)
    end
  end

  defp make_executable(path) do
    case System.cmd("chmod", ["+x", path]) do
      {_, 0} -> :ok
      {output, _} -> {:error, output}
    end
  end
end
