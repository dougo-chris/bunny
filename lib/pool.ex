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
          name: {:local, :"#{channel_name}_channel_pool"},
          worker_module: BunnyPoolChannel,
          size: channel_size,
          max_overflow: channel_overflow,
          strategy: @channel_strategy
        ]

        [
          %{
            id: :"#{channel_name}_connection_pool",
            start: {BunnyPoolConnection, :start_link, [worker_opts]}
          },
          :poolboy.child_spec(
            :"#{channel_name}_channel_pool",
            pool_opts,
            worker_opts
          )
          | children
        ]
      end)

    Supervisor.start_link(children, strategy: :one_for_one)
  end

  def get_connection(name) do
    GenServer.call(BunnyPoolConnection.name(name), :connection)
  end

  def with_channel(channel_name, func) do
    :poolboy.transaction(:"#{channel_name}_channel_pool", fn pid ->
      with {:ok, channel, config} <- GenServer.call(pid, :channel) do
        func.(channel, config)
      end
    end)
  end
end
