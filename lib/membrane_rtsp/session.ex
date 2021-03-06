defmodule Membrane.RTSP.Session do
  @moduledoc """
  This module represents an active Session.
  """
  alias Membrane.RTSP
  alias Membrane.RTSP.{Request, Response, Transport}
  alias Membrane.RTSP.Session.{Container, Manager}
  alias Membrane.RTSP.Supervisor, as: RTSPSupervisor

  defstruct [:manager, :container]

  @type t :: %__MODULE__{
          manager: pid(),
          container: pid()
        }

  @doc """
  Start and links a Session.

  If an error will occur during startup, an exit signal will be sent. Session
  started this way can be stopped by calling `Supervisor.stop/3`.
  """
  def start_link(url, transport \\ Transport.TCPSocket, options \\ []) do
    with {:ok, container} <- Container.start_link(transport, url, options) do
      {Manager, session_pid, _, _} =
        container
        |> Supervisor.which_children()
        |> List.keyfind(Manager, 0)

      %__MODULE__{manager: session_pid, container: container}
    end
  end

  @doc """
  Starts a Session under a `DynamicSupervisor`.
  """
  @spec new(pid(), binary(), module(), Keyword.t()) :: :ignore | {:error, atom()} | {:ok, t()}
  def new(supervisor, url, transport \\ Transport.TCPSocket, options \\ []) do
    with {:ok, container} <- RTSPSupervisor.start_child(supervisor, transport, url, options) do
      {Manager, session_pid, _, _} =
        container
        |> Supervisor.which_children()
        |> List.keyfind(Manager, 0)

      {:ok, %__MODULE__{manager: session_pid, container: container}}
    end
  end

  @doc """
  Closes open Session that was started using `Session.new/4`.
  """
  @spec close(pid(), t()) :: :ok | {:error, atom()}
  def close(supervisor, %__MODULE__{container: container}) do
    DynamicSupervisor.terminate_child(supervisor, container)
  end

  @doc """
  Executes the request on a given session.

  Before execution populates with a default headers setting `Session`
  and `User-Agent` header. If the URI contains credentials they will also
  be added unless `Authorization` header is present in request.
  """
  @spec request(t(), binary(), RTSP.headers(), binary(), nil | binary()) :: Response.result()
  def request(session, method, headers \\ [], body \\ "", path \\ nil) do
    %__MODULE__{manager: manager} = session

    request = %Request{method: method, headers: headers, body: body, path: path}
    Manager.request(manager, request)
  end
end
