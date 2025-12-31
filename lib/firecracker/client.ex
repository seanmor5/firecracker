defmodule Firecracker.Client do
  @moduledoc false
  alias Req.Request
  alias Firecracker.Model

  @type result :: {:ok, term()} | {:error, String.t()}

  ## Describe

  @describe_endpoints %{
    instance: "/",
    balloon: "/balloon",
    balloon_statistics: "/balloon/statistics",
    machine_config: "/machine-config",
    mmds: "/mmds",
    vm_config: "/vm/config",
    version: "/version"
  }

  @spec describe(Request.t(), atom()) :: result()
  def describe(%Request{} = req, key) do
    req
    |> Req.get!(url: Map.fetch!(@describe_endpoints, key))
    |> parse_resp(200)
  end

  @spec put(Request.t(), struct()) :: result()
  def put(req, model) do
    req
    |> Req.put!(url: Model.endpoint(model), json: Model.put(model))
    |> parse_resp(204)
  end

  @spec patch(Request.t(), struct()) :: result()
  def patch(
        req,
        %Firecracker.Balloon{stats_polling_interval_s: interval, amount_mib: amount} = balloon
      )
      when not is_nil(interval) and not is_nil(amount) do
    resp =
      req
      |> Req.put!(url: "/balloon/statistics", json: Model.patch(balloon))
      |> parse_resp(204)

    with {:ok, _} <- resp do
      req
      |> Req.put!(url: Model.endpoint(balloon), json: Model.patch(balloon))
      |> parse_resp(204)
    end
  end

  def patch(req, %Firecracker.Balloon{stats_polling_interval_s: interval} = balloon)
      when not is_nil(interval) do
    req
    |> Req.put!(url: "/balloon/statistics", json: Model.patch(balloon))
    |> parse_resp(204)
  end

  def patch(req, %Firecracker.Balloon{amount_mib: amount} = balloon) when not is_nil(amount) do
    req
    |> Req.put!(url: Model.endpoint(balloon), json: Model.patch(balloon))
    |> parse_resp(204)
  end

  def patch(req, model) do
    req
    |> Req.put!(url: Model.endpoint(model), json: Model.patch(model))
    |> parse_resp(204)
  end

  @spec create_sync_action(Request.t(), map()) :: result()
  def create_sync_action(%Request{} = req, attrs \\ %{}) do
    req
    |> Req.put!(url: "/actions", json: attrs)
    |> parse_resp(204)
  end

  @spec create_snapshot(Request.t(), map()) :: result()
  def create_snapshot(%Request{} = req, attrs \\ %{}) do
    req
    |> Req.put!(url: "/snapshot/create", json: attrs)
    |> parse_resp(204)
  end

  @spec load_snapshot(Request.t(), map()) :: result()
  def load_snapshot(%Request{} = req, attrs \\ %{}) do
    req
    |> Req.put!(url: "/snapshot/load", json: attrs)
    |> parse_resp(204)
  end

  @spec patch_vm(Request.t(), map()) :: result()
  def patch_vm(%Request{} = req, attrs \\ %{}) do
    req
    |> Req.patch!(url: "/vm", json: attrs)
    |> parse_resp(204)
  end

  defp parse_resp(resp, expected_code) do
    case resp do
      %{status: ^expected_code, body: body} -> {:ok, body}
      %{body: %{"fault_message" => error}} -> {:error, error}
    end
  end
end
