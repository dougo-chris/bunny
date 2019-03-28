defmodule Linklab.Bunny.Consumer do
  @moduledoc false

  alias AMQP.Basic, as: AMQPBasic
  alias Linklab.Bunny.Pool, as: BunnyPool

  @callback setup(AMQP.Channel.t, map) :: {:ok, map} | {:error, String.t}
  @callback basic_deliver(AMQP.Channel.t, map, any, map) :: {:ok, map} | {:error, String.t}
  @callback basic_consume_ok(AMQP.Channel.t, map, map) :: {:ok, map} | {:error, String.t}
  @callback basic_cancel(AMQP.Channel.t, map, map) :: {:ok, map} | {:error, String.t}
  @callback basic_cancel_ok(AMQP.Channel.t, map, map) :: {:ok, map} | {:error, String.t}
  @callback basic_return(AMQP.Channel.t, map, any, map) :: {:ok, map} | {:error, String.t}

  defmacro __using__(_opts) do
    quote do
      import Linklab.Bunny.Consumer

      @behaviour Linklab.Bunny.Consumer

      def setup(_, opts), do: {:ok, opts}
      def basic_deliver(_, opts, _, _), do: {:ok, opts}
      def basic_consume_ok(_, opts, _), do: {:ok, opts}
      def basic_cancel(_, opts, _), do: {:ok, opts}
      def basic_cancel_ok(_, opts, _), do: {:ok, opts}
      def basic_return(_, opts, _, _), do: {:ok, opts}

      defoverridable Linklab.Bunny.Consumer
    end
  end

  def publish(name, routing_key, payload, options \\ []) do
    BunnyPool.with_channel(name, fn channel, %{exchange: exchange} ->
      AMQPBasic.publish(channel, exchange, routing_key, payload, options)
    end)
  end

  def ack(channel, tag) do
    AMQPBasic.ack(channel, tag)
  end

  def reject(channel, tag, options) do
    AMQPBasic.reject(channel, tag, options)
  end
end
