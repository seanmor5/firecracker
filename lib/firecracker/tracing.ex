defmodule Firecracker.Tracing do
  @moduledoc """
  Firecracker request tracing.

  This module provides basic tracing capabilities for Firecracker API requests
  by adding custom request/response steps to the Req struct.
  """

  require Logger

  @doc """
  Attaches a logger tracer to the given Req struct.

  The logger tracer logs both requests and responses.

  ## Options

    * `:level` - The log level to use. Defaults to `:info`.
  """
  def log(req, opts \\ []) do
    level = Keyword.get(opts, :level, :info)

    req
    |> Req.Request.append_request_steps(logger_request: &log_request(&1, level))
    |> Req.Request.append_response_steps(logger_response: &log_response(&1, level))
  end

  defp log_request(request, level) do
    method = request.method |> to_string() |> String.upcase()
    url = build_url(request)

    Logger.log(level, "[Firecracker] Request: #{method} #{url}")

    if request.body do
      Logger.log(level, "[Firecracker] Request Body: #{inspect(to_string(request.body))}")
    end

    request
  end

  defp log_response({request, response}, level) do
    method = request.method |> to_string() |> String.upcase()
    url = build_url(request)
    status = response.status

    Logger.log(level, "[Firecracker] Response: #{method} #{url} -> #{status}")

    if response.body && response.body != "" do
      Logger.log(level, "[Firecracker] Response Body: #{inspect(response.body)}")
    end

    {request, response}
  end

  @doc """
  Attaches a file tracer to the given Req struct.

  The file tracer writes both requests and responses to a file.

  ## Options

    * `:path` - The path to the file to write traces to. Required.
  """
  def file(req, opts \\ []) do
    path = Keyword.fetch!(opts, :path)

    File.touch!(path)

    req
    |> Req.Request.append_request_steps(file_request: &write_request(&1, path))
    |> Req.Request.append_response_steps(file_response: &write_response(&1, path))
  end

  defp write_request(request, path) do
    method = request.method |> to_string() |> String.upcase()
    url = build_url(request)
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()

    entry = """
    [#{timestamp}] REQUEST
    Method: #{method}
    URL: #{url}
    Body: #{inspect(request.body)}
    ---
    """

    File.write!(path, entry, [:append])
    request
  end

  defp write_response({request, response}, path) do
    method = request.method |> to_string() |> String.upcase()
    url = build_url(request)
    status = response.status
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()

    entry = """
    [#{timestamp}] RESPONSE
    Method: #{method}
    URL: #{url}
    Status: #{status}
    Body: #{inspect(response.body)}
    ---
    """

    File.write!(path, entry, [:append])
    {request, response}
  end

  defp build_url(request) do
    case request do
      %{url: %URI{path: path}} when is_binary(path) -> path
      %{url: url} when is_binary(url) -> url
      _ -> "unknown"
    end
  end
end
