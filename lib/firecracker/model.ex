defprotocol Firecracker.Model do
  @moduledoc false

  # This is an internal protocol to make it easier to control which
  # fields are allowed to be updated at different points in the VM
  # lifecycle. The functions:
  #
  #   * `validate_change!/3` - validates whether the given options can be
  #     changed at the current VM state
  #
  #   * `put/1` - returns the API representation for the model for
  #     modifying the VM before boot
  #
  #   * `patch/1` - returns the API representation for the model for
  #     modifying the VM after boot
  #
  #   * `endpoint/1` - returns the API endpoint for the model

  def validate_change!(struct, opts, state)

  def endpoint(struct)

  def put(struct)

  def patch(struct)
end

defimpl Firecracker.Model, for: Any do
  defmacro __deriving__(module, _struct, options) do
    pre_boot_schema = Keyword.fetch!(options, :pre_boot_schema)
    post_boot_schema = Keyword.fetch!(options, :post_boot_schema)
    endpoint = Keyword.fetch!(options, :endpoint)
    id_key = Keyword.get(options, :id_key, nil)

    quote do
      defimpl Firecracker.Model, for: unquote(module) do
        def validate_change!(_struct, opts, state) when state in [:initial, :started] do
          NimbleOptions.validate!(opts, unquote(Macro.escape(pre_boot_schema)))
        end

        def validate_change!(_struct, opts, state)
            when state in [:running, :paused, :shutdown] do
          NimbleOptions.validate!(opts, unquote(Macro.escape(post_boot_schema)))
        end

        def validate_change!(_struct, _opts, :exited) do
          raise ArgumentError,
                "cannot modify configuration when VM is in state #{inspect(:exited)}"
        end

        def put(struct) do
          struct
          |> Map.from_struct()
          |> Map.new(fn
            {k, %Firecracker.RateLimiter{} = rl} -> {k, Firecracker.RateLimiter.model(rl)}
            {k, v} -> {k, v}
          end)
          |> Map.delete(:applied?)
          |> to_api_config()
        end

        @post_boot_keys unquote(Macro.escape(post_boot_schema)).schema |> Keyword.keys() |> MapSet.new()

        def patch(struct) do
          struct
          |> Map.from_struct()
          |> Map.new(fn {k, v} ->
            if MapSet.member?(@post_boot_keys, k) do
              case v do
                %Firecracker.RateLimiter{} = rl -> {k, Firecracker.RateLimiter.model(rl)}
                _ -> {k, v}
              end
            else
              {k, nil}
            end
          end)
          |> to_api_config()
        end

        # this conditional needs to be before the function, because otherwise
        # we compile invalid code for modules that do not have an id_key, which
        # produces typing violations, e.g. because we try `struct.nil`
        if is_nil(unquote(id_key)) do
          def endpoint(struct) do
            unquote(endpoint)
          end
        else
          def endpoint(struct) do
            Path.join(unquote(endpoint), struct.unquote(id_key))
          end
        end

        defp to_api_config(config) do
          config
          |> Map.new(fn {k, v} -> {Atom.to_string(k), v} end)
        end
      end
    end
  end

  def validate_change!(struct, _, _) do
    raise Protocol.UndefinedError, protocol: @protocol, value: struct
  end

  def endpoint(struct) do
    raise Protocol.UndefinedError, protocol: @protocol, value: struct
  end

  def put(struct) do
    raise Protocol.UndefinedError, protocol: @protocol, value: struct
  end

  def patch(struct) do
    raise Protocol.UndefinedError, protocol: @protocol, value: struct
  end
end
