defmodule Linklab.Bunny.Consumer do
  @moduledoc false

  alias AMQP.Basic, as: AMQPBasic
  alias Linklab.Bunny.Pool, as: BunnyPool

  @callback setup(channel :: AMQP.Channel.t(), config :: map) :: :ok | no_return
  @callback basic_deliver(channel :: AMQP.Channel.t(), payload :: any, meta :: map) ::
              :ok | no_return
  @callback basic_return(channel :: AMQP.Channel.t(), payload :: any, meta :: map) ::
              :ok | no_return
  @callback basic_consume_ok(channel :: AMQP.Channel.t(), meta :: map) :: :ok | no_return
  @callback basic_cancel(channel :: AMQP.Channel.t(), meta :: map) :: :ok | no_return
  @callback basic_cancel_ok(channel :: AMQP.Channel.t(), meta :: map) :: :ok | no_return

  defmacro __using__(_opts) do
    quote do
      import Linklab.Bunny.Consumer

      @behaviour Linklab.Bunny.Consumer

      def setup(_, _config), do: :ok
      def basic_deliver(_, _, _), do: :ok
      def basic_return(_, _, _), do: :ok
      def basic_consume_ok(_, _), do: :ok
      def basic_cancel(_, _), do: :ok
      def basic_cancel_ok(_, _), do: :ok

      defoverridable Linklab.Bunny.Consumer
    end
  end

  def publish(channel_name, routing_key, payload, options \\ []) do
    BunnyPool.with_channel(channel_name, fn channel, %{exchange: exchange} ->
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
