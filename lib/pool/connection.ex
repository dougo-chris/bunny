defmodule Linklab.Bunny.Pool.Connection do
  @moduledoc false
  use GenServer
  use AMQP

  @reconnect_after_ms 5_000

  def start_link(%{name: name} = opts) do
    GenServer.start_link(__MODULE__, opts, [name: name(name)])
  end

  def name(name) do
    :"#{name}_connection_pool"
  end

  def init(opts) do
    Process.flag(:trap_exit, true)
    send(self(), :connect)
    {:ok, %{connection: nil, opts: opts, status: :disconnected}}
  end

  def handle_call(:connection, _from, %{connection: connection, status: :connected} = state) do
    {:reply, {:ok, connection}, state}
  end

  def handle_call(:connection, _from, %{status: :disconnected} = state) do
    {:reply, {:error, "no connection"}, state}
  end

  def handle_call(_message, _from, state) do
    {:reply, {:error, "invalid call"}, state}
  end

  def handle_info(:connect, %{opts: opts, status: :disconnected} = state) do
    connection_options = [
      host: Map.get(opts, :host),
      port: Map.get(opts, :port, 5672),
      username: Map.get(opts, :username),
      password: Map.get(opts, :password),
      heartbeat: Map.get(opts, :heartbeat, 30)
    ]

    case Connection.open(connection_options) do
      {:ok, connection} ->
        Process.monitor(connection.pid)
        {:noreply, %{state | connection: connection, status: :connected}}

      _ ->
        Process.send_after(self(), :connect, @reconnect_after_ms)
        {:noreply, state}
    end
  end

  def handle_info(:connect, state) do
    {:noreply, state}
  end

  def handle_info({:EXIT, _pid, _reason}, state) do
    # IO.inspect("Exit message from: #{inspect pid}, reason: #{inspect reason}")
    {:noreply, state}
  end

  def handle_info({:DOWN, _ref, :process, _pid, _reason}, %{status: :connected} = state) do
    Process.send_after(self(), :connect, @reconnect_after_ms)
    {:noreply, %{state | connection: nil, status: :disconnected}}
  end

  def handle_info(_message, state) do
    {:noreply, state}
  end

  def terminate(_reason, %{connection: connection, status: :connected}) do
    Connection.close(connection)
  catch
    _, _ -> :ok
  end

  def terminate(_reason, _state) do
    :ok
  end
end
