# Firecracker

[![Docs](https://img.shields.io/badge/docs-latest-blue.svg)](https://seanmor5.github.io/firecracker/Firecracker.html)

An Elixir SDK for interacting with [Firecracker](https://github.com/firecracker-microvm/firecracker) virtual machines.

This library provides a low-level interface for creating, configuring, and managing Firecracker microVMs programmatically. It closely follows the Firecracker API surface, but with the goal of providing an idiomatic Elixir interface.

## System Requirements

Firecracker requires a Linux host with KVM support. You can use the [checkenv devtool](https://github.com/firecracker-microvm/firecracker/blob/main/tools/devtool) provided by the Firecracker developers to verify your system supports running Firecracker.

## Installation

Until this is released on Hex, you can use the dependency from GitHub:

```elixir
def deps do
  [
    {:firecracker, github: "seanmor5/firecracker"}
  ]
end
```

After installation, you can use the provided mix task to install the Firecracker binaries:

```bash
mix firecracker.install
```

This installs the Firecracker and Jailer binaries to `~/.firecracker/bin`.

## Usage

### Creating and Starting a VM

```elixir
vm =
  Firecracker.new()
  |> Firecracker.configure(:boot_source, kernel_image_path: "/path/to/kernel")
  |> Firecracker.add(:drive, "rootfs",
    path_on_host: "/path/to/rootfs.ext4",
    is_root_device: true,
    is_read_only: false
  )
  |> Firecracker.start()
  |> Firecracker.boot()
```

### Stopping a VM

```elixir
Firecracker.stop(vm)
```

### Pausing and Resuming

```elixir
paused = Firecracker.pause(vm)
resumed = Firecracker.resume(paused)
```

## License

Copyright (c) 2025 Sean Moriarity

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
