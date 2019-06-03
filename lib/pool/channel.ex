defmodule Linklab.Bunny.Pool.Channel do
  @moduledoc false
  use GenServer
  use AMQP

  alias Linklab.Bunny.Pool

  @reconnect_after_ms 5_000

  def start_link(opts) do
    state = %{
      channel_name: Keyword.get(opts, :channel_name),
      handler: Keyword.get(opts, :handler),
      config: Keyword.get(opts, :config),
      channel: nil,
      status: :disconnected
    }

    GenServer.start_link(__MODULE__, state)
  end

  def name(channel_name) do
    :"#{channel_name}_pool_channel"
  end

  def init(state) do
    Process.flag(:trap_exit, true)
    send(self(), :connect)
    {:ok, state}
  end

  def handle_call(
        :channel,
        _from,
        %{channel: channel, config: config, status: :connected} = state
      ) do
    {:reply, {:ok, channel, config}, state}
  end

  def handle_call(:channel, _from, %{status: :disconnected} = state) do
    {:reply, {:error, "no channel"}, state}
  end

  def handle_call(message, _from, state) do
    {:reply, {:error, "invalid call message #{inspect(message)}"}, state}
  end

  def handle_info(:connect, %{channel_name: channel_name, status: :disconnected} = state) do
    with {:ok, connection} <- Pool.get_connection(channel_name),
         {:ok, channel} <- Channel.open(connection) do
      :ok = handler_setup(channel, state)
      Process.monitor(connection.pid)
      {:noreply, %{state | channel: channel, status: :connected}}
    else
      _ ->
        Process.send_after(self(), :connect, @reconnect_after_ms)
        {:noreply, state}
    end
  end

  # Deal with consumer messages
  def handle_info({:basic_deliver, payload, meta}, state) do
    :ok = handler_basic_deliver(state, payload, meta)
  end

  # Deal with producer messages
  def handle_info({:basic_return, payload, meta}, state) do
    :ok = handler_basic_return(state, payload, meta)
    {:noreply, state}
  end

  # Confirmation sent by the broker after registering this process as a consumer
  def handle_info({:basic_consume_ok, meta}, state) do
    :ok = handler_basic_consume_ok(state, meta)
    {:noreply, state}
  end

  # Sent by the broker when the consumer is unexpectedly cancelled (such as after a queue deletion)
  def handle_info({:basic_cancel, meta}, %{status: :connected} = state) do
    :ok = handler_basic_cancel(state, meta)
    Process.send_after(self(), :connect, @reconnect_after_ms)
    {:noreply, %{state | status: :disconnected}}
  end

  # Confirmation sent by the broker to the consumer process after a Basic.cancel
  def handle_info({:basic_cancel_ok, meta}, %{status: :connected} = state) do
    :ok = handler_basic_cancel_ok(state, meta)
    Process.send_after(self(), :connect, @reconnect_after_ms)
    {:noreply, %{state | status: :disconnected}}
  end

  def handle_info({:EXIT, _pid, _reason}, state) do
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
    Channel.close(channel)
  catch
    _, _ -> :ok
  end

  def terminate(_reason, _state) do
    :ok
  end

  defp handler_setup(channel, %{handler: handler, config: config}) do
    handler.setup(channel, config)
  end

  def handler_basic_deliver(%{handler: handler, channel: channel}, payload, meta) do
    handler.basic_deliver(channel, payload, meta)
  end

  def handler_basic_return(%{handler: handler, channel: channel}, payload, meta) do
    handler.basic_return(channel, payload, meta)
  end

  def handler_basic_consume_ok(%{handler: handler, channel: channel}, meta) do
    handler.basic_consume_ok(channel, meta)
  end

  def handler_basic_cancel(%{handler: handler, channel: channel}, meta) do
    handler.basic_cancel(channel, meta)
  end

  def handler_basic_cancel_ok(%{handler: handler, channel: channel}, meta) do
    handler.basic_cancel_ok(channel, meta)
  end
end
