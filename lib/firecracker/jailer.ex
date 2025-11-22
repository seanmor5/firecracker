defmodule Firecracker.Jailer do
  @moduledoc false

  @schema NimbleOptions.new!(
            uid: [type: :non_neg_integer, required: true],
            gid: [type: :non_neg_integer, required: true],
            parent_cgroup: [type: :string, required: false],
            cgroups: [type: :keyword_list, required: false],
            netns: [type: :string, required: false],
            resource_limits: [type: :keyword_list, required: false],
            daemonize: [type: :boolean, required: false],
            new_pid_ns: [type: :boolean, required: false],
            jailer_path: [type: :string, required: false],
            cgroup_version: [type: :string, required: false],
            chroot_base_dir: [type: :string, required: false]
          )

  defstruct [
    # args
    :uid,
    :gid,
    :parent_cgroup,
    :cgroups,
    :netns,
    :resource_limits,
    :daemonize,
    :new_pid_ns,
    :jailer_path,
    cgroup_version: "1",
    chroot_base_dir: "/srv/jailer"
  ]

  @type t :: %__MODULE__{
          uid: non_neg_integer() | nil,
          gid: non_neg_integer() | nil,
          parent_cgroup: String.t() | nil,
          cgroups: %{String.t() => term()} | nil,
          netns: String.t() | nil,
          resource_limits: %{String.t() => term()} | nil,
          daemonize: boolean() | nil,
          new_pid_ns: boolean() | nil,
          jailer_path: String.t() | nil,
          cgroup_version: String.t(),
          chroot_base_dir: String.t()
        }

  @doc false
  def validate_options!(opts) do
    NimbleOptions.validate!(opts, @schema)
  end
end
