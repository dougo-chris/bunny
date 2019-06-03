defmodule Linklab.Bunny.Pool do
  @moduledoc false
  use GenServer

  alias Linklab.Bunny.Pool.Channel, as: BunnyPoolChannel
  alias Linklab.Bunny.Pool.Connection, as: BunnyPoolConnection

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
          name: {:local, BunnyPoolChannel.name(channel_name)},
          worker_module: BunnyPoolChannel,
          size: channel_size,
          max_overflow: channel_overflow,
          strategy: @channel_strategy
        ]

        [
          %{
            id: BunnyPoolConnection.name(channel_name),
            start: {BunnyPoolConnection, :start_link, [worker_opts]}
          },
          :poolboy.child_spec(
            BunnyPoolChannel.name(channel_name),
            pool_opts,
            worker_opts
          )
          | children
        ]
      end)

    Supervisor.start_link(children, strategy: :one_for_one)
  end

  def get_connection(channel_name) do
    GenServer.call(BunnyPoolConnection.name(channel_name), :connection)
  end

  def with_channel(channel_name, func) do
    :poolboy.transaction(BunnyPoolChannel.name(channel_name), fn pid ->
      with {:ok, channel, config} <- GenServer.call(pid, :channel) do
        func.(channel, config)
      end
    end)
  end
end
