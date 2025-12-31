{:ok, _} = TempFiles.start_link()

exclude =
  case TestRequirements.installed_version() do
    %Version{} = v ->
      IO.puts("Firecracker #{v} detected")
      nil

    nil ->
      IO.puts("Firecracker not found or not working, skipping :vm tests")
      [:vm]
  end

ExUnit.start(exclude: exclude)
