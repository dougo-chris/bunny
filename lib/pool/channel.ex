defmodule Linklab.Bunny.Pool.Channel do
  use GenServer
  use AMQP

  alias Linklab.Bunny.Pool

  @reconnect_after_ms 5_000

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def setup(channel, %{handler: handler} = opts), do: handler.setup(channel, opts)
  def setup(_, opts), do: {:ok, opts}

  def basic_deliver(channel, %{handler: handler} = opts, payload, meta), do: handler.basic_deliver(channel, opts, payload, meta)
  def basic_deliver(_, opts, _, _), do: {:ok, opts}

  def basic_return(channel, %{handler: handler} = opts, payload, meta), do: handler.basic_return(channel, opts, payload, meta)
  def basic_return(_, opts, _, _), do: {:ok, opts}

  def basic_consume_ok(channel, %{handler: handler} = opts, meta), do: handler.basic_consume_ok(channel, opts, meta)
  def basic_consume_ok(_, opts, _), do: {:ok, opts}

  def basic_cancel(channel, %{handler: handler} = opts, meta), do: handler.basic_cancel(channel, opts, meta)
  def basic_cancel(_, opts, _), do: {:ok, opts}

  def basic_cancel_ok(channel, %{handler: handler} = opts, meta), do: handler.basic_cancel_ok(channel, opts, meta)
  def basic_cancel_ok(_, opts, _), do: {:ok, opts}

  def init(opts) do
    Process.flag(:trap_exit, true)
    send(self(), :connect)
    {:ok, %{channel: nil, opts: opts, status: :disconnected}}
  end

  def handle_call(:channel, _from, %{channel: channel, opts: opts, status: :connected} = state) do
    {:reply, {:ok, channel, opts}, state}
  end

  def handle_call(:channel, _from, %{status: :disconnected} = state) do
    {:reply, {:error, "no channel"}, state}
  end

  def handle_call(message, _from, state) do
    {:reply, {:error, "invalid call message #{inspect message}"}, state}
  end

  def handle_info(:connect, %{opts: %{name: name} = opts, status: :disconnected} = state) do
    with {:ok, connection} <- Pool.get_connection(name),
        {:ok, channel} <- Channel.open(connection),
        {:ok, opts} <- setup(channel, opts) do
      Process.monitor(connection.pid)
      {:noreply, %{state | channel: channel, opts: opts, status: :connected}}
    else
      _ ->
        Process.send_after(self(), :connect, @reconnect_after_ms)
        {:noreply, state}
    end
  end

  # Deal with consumer messages
  def handle_info({:basic_deliver, payload, meta}, %{channel: channel, opts: opts} = state) do
    case basic_deliver(channel, opts, payload, meta) do
      {:ok, opts} ->
        {:noreply, %{state | opts: opts, status: :disconnected}}
      _ ->
        {:noreply, %{state | status: :disconnected}}
    end
  end

  # Deal with producer messages
  def handle_info({:basic_return, payload, meta}, %{channel: channel, opts: opts} = state) do
    IO.inspect({:basic_return, self()})
    case basic_return(channel, opts, payload, meta) do
      {:ok, opts} ->
        {:noreply, %{state | opts: opts}}
      _ ->
        {:noreply, state}
    end
  end

  # Confirmation sent by the broker after registering this process as a consumer
  def handle_info({:basic_consume_ok, meta}, %{channel: channel, opts: opts} = state) do
    case basic_consume_ok(channel, opts, meta) do
      {:ok, opts} ->
        {:noreply, %{state | opts: opts}}
      _ ->
        {:noreply, state}
    end
  end

  # Sent by the broker when the consumer is unexpectedly cancelled (such as after a queue deletion)
  def handle_info({:basic_cancel, meta}, %{channel: channel, opts: opts, status: :connected} = state) do
    case basic_cancel(channel, opts, meta) do
      {:ok, opts} ->
        Process.send_after(self(), :connect, @reconnect_after_ms)
        {:noreply, %{state | opts: opts, status: :disconnected}}
      _ ->
        Process.send_after(self(), :connect, @reconnect_after_ms)
        {:noreply, %{state | status: :disconnected}}
    end
  end

  # Confirmation sent by the broker to the consumer process after a Basic.cancel
  def handle_info({:basic_cancel_ok, meta}, %{channel: channel, opts: opts, status: :connected} = state) do
    case basic_cancel_ok(channel, opts, meta) do
      {:ok, opts} ->
        Process.send_after(self(), :connect, @reconnect_after_ms)
        {:noreply, %{state | opts: opts, status: :disconnected}}
      _ ->
        Process.send_after(self(), :connect, @reconnect_after_ms)
        {:noreply, %{state | status: :disconnected}}
    end
  end

  def handle_info({:EXIT, _pid, _reason}, state) do
    # IO.inspect("Exit message from: #{inspect pid}, reason: #{inspect reason}")
    {:noreply, state}
  end

  def handle_info({:DOWN, _ref, :process, _pid, _reason}, %{status: :connected} = state) do
    Process.send_after(self(), :connect, @reconnect_after_ms)
    {:noreply, %{state | status: :disconnected}}
  end

  def handle_info(_message, state) do
    {:noreply, state}
  end

  def terminate(_reason, %{channel: channel, status: :connected}) do
    try do
      Channel.close(channel)
    catch
      _, _ -> :ok
    end
  end

  def terminate(_reason, _state) do
    :ok
  end
end
