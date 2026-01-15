defmodule Firecracker.Version do
  @moduledoc """
  Version compatibility management for the Firecracker SDK.

  This module provides version detection, comparison, and feature compatibility
  checking to ensure the SDK only uses APIs supported by the target Firecracker
  version.

  ## Version Detection

  The SDK can automatically detect the Firecracker version at runtime:

      {:ok, version} = Firecracker.Version.detect(vm)
      # => {:ok, %Version{major: 1, minor: 10, patch: 0}}

  ## Feature Compatibility

  Each feature in the SDK has a minimum required version. You can check
  compatibility before using a feature:

      Firecracker.Version.supports?(version, :memory_hotplug)
      # => true

      Firecracker.Version.supports?("1.5.0", :balloon_hinting)
      # => false (requires 1.14.0+)

  ## Enforcement Modes

  The SDK supports different version enforcement modes:

    * `:strict` - Raises an error if a feature is used on an incompatible version
    * `:warn` - Logs a warning but allows the operation to proceed
    * `:none` - No version checking (default for backwards compatibility)

  Configure the enforcement mode when creating a VM:

      Firecracker.new(version_enforcement: :strict, target_version: "1.10.0")

  ## Minimum Supported Version

  This SDK targets Firecracker v1.0.0 and later. Some features require
  newer versions as documented in the feature registry.
  """

  defstruct [:major, :minor, :patch, :prerelease]

  @type t :: %__MODULE__{
          major: non_neg_integer(),
          minor: non_neg_integer(),
          patch: non_neg_integer(),
          prerelease: String.t() | nil
        }

  @type version_input :: t() | String.t() | {non_neg_integer(), non_neg_integer(), non_neg_integer()}

  @type enforcement_mode :: :strict | :warn | :none

  # Feature registry with minimum version requirements
  # Format: feature_key => {major, minor, patch}
  @feature_versions %{
    # Core features (available since 1.0)
    balloon: {1, 0, 0},
    boot_source: {1, 0, 0},
    cpu_config: {1, 0, 0},
    drive: {1, 0, 0},
    entropy: {1, 0, 0},
    logger: {1, 0, 0},
    machine_config: {1, 0, 0},
    metrics: {1, 0, 0},
    mmds: {1, 0, 0},
    mmds_config: {1, 0, 0},
    network_interface: {1, 0, 0},
    snapshot: {1, 0, 0},
    vsock: {1, 0, 0},
    rate_limiter: {1, 0, 0},

    # Features added in later versions
    serial: {1, 13, 0},
    pmem: {1, 14, 0},
    memory_hotplug: {1, 14, 0},
    balloon_hinting: {1, 14, 0},
    balloon_stats: {1, 0, 0},

    # Snapshot features
    snapshot_diff: {1, 0, 0},
    snapshot_mem_backend: {1, 0, 0},

    # MMDS features
    mmds_v2: {1, 13, 0},
    mmds_patch: {1, 0, 0},

    # Machine config features
    huge_pages: {1, 0, 0},
    smt: {1, 0, 0},
    track_dirty_pages: {1, 0, 0}
  }

  @doc """
  Returns the minimum supported Firecracker version for this SDK.
  """
  @spec minimum_version() :: t()
  def minimum_version, do: %__MODULE__{major: 1, minor: 0, patch: 0}

  @doc """
  Returns the recommended Firecracker version for full feature support.
  """
  @spec recommended_version() :: t()
  def recommended_version, do: %__MODULE__{major: 1, minor: 14, patch: 0}

  @doc """
  Parses a version string into a Version struct.

  ## Examples

      iex> Firecracker.Version.parse("1.10.2")
      {:ok, %Firecracker.Version{major: 1, minor: 10, patch: 2}}

      iex> Firecracker.Version.parse("1.14.0-dev")
      {:ok, %Firecracker.Version{major: 1, minor: 14, patch: 0, prerelease: "dev"}}

      iex> Firecracker.Version.parse("invalid")
      {:error, "invalid version format"}
  """
  @spec parse(String.t()) :: {:ok, t()} | {:error, String.t()}
  def parse(version_string) when is_binary(version_string) do
    # Handle optional 'v' prefix
    version_string = String.trim_leading(version_string, "v")

    case Regex.run(~r/^(\d+)\.(\d+)\.(\d+)(?:-(.+))?$/, version_string) do
      [_, major, minor, patch] ->
        {:ok,
         %__MODULE__{
           major: String.to_integer(major),
           minor: String.to_integer(minor),
           patch: String.to_integer(patch)
         }}

      [_, major, minor, patch, prerelease] ->
        {:ok,
         %__MODULE__{
           major: String.to_integer(major),
           minor: String.to_integer(minor),
           patch: String.to_integer(patch),
           prerelease: prerelease
         }}

      _ ->
        {:error, "invalid version format"}
    end
  end

  @doc """
  Parses a version string, raising on invalid input.
  """
  @spec parse!(String.t()) :: t()
  def parse!(version_string) do
    case parse(version_string) do
      {:ok, version} -> version
      {:error, msg} -> raise ArgumentError, msg
    end
  end

  @doc """
  Converts a version to a comparable tuple.
  """
  @spec to_tuple(version_input()) :: {non_neg_integer(), non_neg_integer(), non_neg_integer()}
  def to_tuple(%__MODULE__{major: major, minor: minor, patch: patch}) do
    {major, minor, patch}
  end

  def to_tuple({major, minor, patch}) when is_integer(major) and is_integer(minor) and is_integer(patch) do
    {major, minor, patch}
  end

  def to_tuple(version_string) when is_binary(version_string) do
    to_tuple(parse!(version_string))
  end

  @doc """
  Converts a version to a string.

  ## Examples

      iex> Firecracker.Version.to_string(%Firecracker.Version{major: 1, minor: 10, patch: 0})
      "1.10.0"
  """
  @spec to_string(t()) :: String.t()
  def to_string(%__MODULE__{major: major, minor: minor, patch: patch, prerelease: nil}) do
    "#{major}.#{minor}.#{patch}"
  end

  def to_string(%__MODULE__{major: major, minor: minor, patch: patch, prerelease: prerelease}) do
    "#{major}.#{minor}.#{patch}-#{prerelease}"
  end

  @doc """
  Compares two versions.

  Returns:
    * `:gt` if v1 > v2
    * `:lt` if v1 < v2
    * `:eq` if v1 == v2

  ## Examples

      iex> Firecracker.Version.compare("1.10.0", "1.9.0")
      :gt

      iex> Firecracker.Version.compare("1.10.0", "1.10.0")
      :eq
  """
  @spec compare(version_input(), version_input()) :: :gt | :lt | :eq
  def compare(v1, v2) do
    t1 = to_tuple(v1)
    t2 = to_tuple(v2)

    cond do
      t1 > t2 -> :gt
      t1 < t2 -> :lt
      true -> :eq
    end
  end

  @doc """
  Returns true if v1 >= v2.
  """
  @spec gte?(version_input(), version_input()) :: boolean()
  def gte?(v1, v2), do: compare(v1, v2) in [:gt, :eq]

  @doc """
  Returns true if v1 > v2.
  """
  @spec gt?(version_input(), version_input()) :: boolean()
  def gt?(v1, v2), do: compare(v1, v2) == :gt

  @doc """
  Returns true if v1 <= v2.
  """
  @spec lte?(version_input(), version_input()) :: boolean()
  def lte?(v1, v2), do: compare(v1, v2) in [:lt, :eq]

  @doc """
  Returns true if v1 < v2.
  """
  @spec lt?(version_input(), version_input()) :: boolean()
  def lt?(v1, v2), do: compare(v1, v2) == :lt

  @doc """
  Checks if a version supports a specific feature.

  ## Examples

      iex> Firecracker.Version.supports?("1.14.0", :memory_hotplug)
      true

      iex> Firecracker.Version.supports?("1.10.0", :memory_hotplug)
      false

      iex> Firecracker.Version.supports?("1.10.0", :balloon)
      true
  """
  @spec supports?(version_input(), atom()) :: boolean()
  def supports?(version, feature) when is_atom(feature) do
    case Map.fetch(@feature_versions, feature) do
      {:ok, min_version} -> gte?(version, min_version)
      :error -> raise ArgumentError, "unknown feature: #{inspect(feature)}"
    end
  end

  @doc """
  Returns the minimum version required for a feature.

  ## Examples

      iex> Firecracker.Version.required_version(:memory_hotplug)
      {1, 14, 0}

      iex> Firecracker.Version.required_version(:balloon)
      {1, 0, 0}
  """
  @spec required_version(atom()) :: {non_neg_integer(), non_neg_integer(), non_neg_integer()}
  def required_version(feature) when is_atom(feature) do
    case Map.fetch(@feature_versions, feature) do
      {:ok, version} -> version
      :error -> raise ArgumentError, "unknown feature: #{inspect(feature)}"
    end
  end

  @doc """
  Returns all features available at a given version.

  ## Examples

      iex> Firecracker.Version.available_features("1.14.0") |> Enum.sort()
      [:balloon, :balloon_hinting, :balloon_stats, :boot_source, ...]
  """
  @spec available_features(version_input()) :: [atom()]
  def available_features(version) do
    @feature_versions
    |> Enum.filter(fn {_feature, min_version} -> gte?(version, min_version) end)
    |> Enum.map(fn {feature, _} -> feature end)
  end

  @doc """
  Returns features that are NOT available at a given version.
  """
  @spec unavailable_features(version_input()) :: [atom()]
  def unavailable_features(version) do
    @feature_versions
    |> Enum.reject(fn {_feature, min_version} -> gte?(version, min_version) end)
    |> Enum.map(fn {feature, _} -> feature end)
  end

  @doc """
  Validates that a feature can be used with a given version.

  Returns `:ok` if compatible, or `{:error, reason}` if not.
  """
  @spec validate_feature(version_input(), atom()) :: :ok | {:error, String.t()}
  def validate_feature(version, feature) do
    if supports?(version, feature) do
      :ok
    else
      {maj, min, patch} = required_version(feature)

      {:error,
       "feature #{inspect(feature)} requires Firecracker >= #{maj}.#{min}.#{patch}, " <>
         "but target version is #{format_version(version)}"}
    end
  end

  @doc """
  Validates a feature and takes action based on enforcement mode.

    * `:strict` - raises an error if incompatible
    * `:warn` - logs a warning and returns :ok
    * `:none` - always returns :ok
  """
  @spec enforce_feature(version_input() | nil, atom(), enforcement_mode()) :: :ok
  def enforce_feature(nil, _feature, _mode), do: :ok

  def enforce_feature(_version, _feature, :none), do: :ok

  def enforce_feature(version, feature, :warn) do
    case validate_feature(version, feature) do
      :ok ->
        :ok

      {:error, msg} ->
        require Logger
        Logger.warning("[Firecracker] #{msg}")
        :ok
    end
  end

  def enforce_feature(version, feature, :strict) do
    case validate_feature(version, feature) do
      :ok -> :ok
      {:error, msg} -> raise ArgumentError, msg
    end
  end

  @doc """
  Returns all registered features and their version requirements.
  """
  @spec feature_registry() :: %{atom() => {non_neg_integer(), non_neg_integer(), non_neg_integer()}}
  def feature_registry, do: @feature_versions

  # Private helpers

  defp format_version(%__MODULE__{} = v), do: __MODULE__.to_string(v)
  defp format_version({maj, min, patch}), do: "#{maj}.#{min}.#{patch}"
  defp format_version(s) when is_binary(s), do: s
end
