defmodule Linklab.Bunny.Pool do
  use GenServer

  @channel_size 5
  @channel_overflow 0
  @channel_strategy :fifo

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    children =
      Enum.reduce(opts, [], fn %{name: name} = opts, children ->

        pool_opts = [
          name:           {:local, :"#{name}_channel_pool"},
          worker_module:  Linklab.Bunny.Pool.Channel,
          size:           opts[:channel_size]     || @channel_size,
          max_overflow:   opts[:channel_overflow] || @channel_overflow,
          strategy:       @channel_strategy
        ]

        [
          %{
            id: :"#{name}_connection_pool",
            start: {Linklab.Bunny.Pool.Connection, :start_link, [opts]}
          },
          :poolboy.child_spec(:"#{name}_channel_pool", pool_opts, opts) |
          children
        ]

      end)

    Supervisor.start_link(children, strategy: :one_for_one)
  end

  def get_connection(name) do
    GenServer.call(Linklab.Bunny.Pool.Connection.name(name), :connection)
  end

  def with_channel(name, func) do
    :poolboy.transaction(:"#{name}_channel_pool", fn pid ->
      with {:ok, channel, opts} <- GenServer.call(pid, :channel) do
        func.(channel, opts)
      end
    end)
  end
end
