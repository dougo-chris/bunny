defmodule Linklab.Bunny.Consumer do

  @callback setup(channel :: AMQP.Channel.t, opts :: map) :: {:ok, opts :: map} | {:error, String.t}
  @callback basic_deliver(channel :: AMQP.Channel.t, opts :: map, payload :: any, meta :: map) :: {:ok, opts :: map} | {:error, String.t}
  @callback basic_consume_ok(channel :: AMQP.Channel.t, opts :: map, meta :: map) :: {:ok, opts :: map} | {:error, String.t}
  @callback basic_cancel(channel :: AMQP.Channel.t, opts :: map, meta :: map) :: {:ok, opts :: map} | {:error, String.t}
  @callback basic_cancel_ok(channel :: AMQP.Channel.t, opts :: map, meta :: map) :: {:ok, opts :: map} | {:error, String.t}
  @callback basic_return(channel :: AMQP.Channel.t, opts :: map, payload :: any, meta :: map) :: {:ok, opts :: map} | {:error, String.t}

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
    Linklab.Bunny.Pool.with_channel(name, fn channel, %{exchange: exchange} ->
      AMQP.Basic.publish(channel, exchange, routing_key, payload, options)
    end)
  end

  def ack(channel, tag) do
    AMQP.Basic.ack(channel, tag)
  end

  def reject(channel, tag, options) do
    AMQP.Basic.reject(channel, tag, options)
  end
end
