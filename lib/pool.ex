defmodule BunnyRabbit.Pool do
  @moduledoc false
  use GenServer

  alias BunnyRabbit.Pool.Channel, as: BunnyRabbitPoolChannel
  alias BunnyRabbit.Pool.Connection, as: BunnyRabbitPoolConnection

  @channel_overflow 0
  @channel_strategy :fifo

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    children =
      Enum.reduce(opts, [], fn worker_opts, children ->
        channel_name = Keyword.get(worker_opts, :channel_name)
        channel_size = Keyword.get(worker_opts, :channel_size)
        channel_overflow = Keyword.get(worker_opts, :channel_overflow, @channel_overflow)

        pool_opts = [
          name: {:local, BunnyRabbitPoolChannel.name(channel_name)},
          worker_module: BunnyRabbitPoolChannel,
          size: channel_size,
          max_overflow: channel_overflow,
          strategy: @channel_strategy
        ]

        [
          %{
            id: BunnyRabbitPoolConnection.name(channel_name),
            start: {BunnyRabbitPoolConnection, :start_link, [worker_opts]}
          },
          :poolboy.child_spec(
            BunnyRabbitPoolChannel.name(channel_name),
            pool_opts,
            worker_opts
          )
          | children
        ]
      end)

    Supervisor.start_link(children, strategy: :one_for_one)
  end

  def get_connection(channel_name) do
    GenServer.call(BunnyRabbitPoolConnection.name(channel_name), :connection)
  end

  def with_channel(channel_name, func) do
    :poolboy.transaction(BunnyRabbitPoolChannel.name(channel_name), fn pid ->
      with {:ok, channel, config} <- GenServer.call(pid, :channel) do
        func.(channel, config)
      end
    end)
  end
end
