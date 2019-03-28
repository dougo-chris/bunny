defmodule Linklab.Bunny.Publisher do
  @moduledoc false

  alias AMQP.Basic, as: AMQPBasic
  alias Linklab.Bunny.Pool, as: BunnyPool

  @spec publish(atom, any, list) :: :ok | AMQP.Basic.error()
  def publish(name, payload, options \\ []) do
    BunnyPool.with_channel(name, fn
      channel, %{exchange: exchange, topic: topic} ->
        AMQPBasic.publish(channel, exchange, topic, payload, options)

      channel, %{exchange: exchange} ->
        AMQPBasic.publish(channel, exchange, "", payload, options)
    end)
  end

  @spec retry(atom, any, list) :: :ok | AMQPBasic.error()
  def retry(name, payload, options \\ []) do
    BunnyPool.with_channel(name, fn
      channel, %{exchange: exchange, topic: topic} ->
        AMQPBasic.publish(channel, exchange, "#{topic}-retry", payload, options)

      channel, %{exchange: exchange} ->
        AMQPBasic.publish(channel, exchange, "retry", payload, options)
    end)
  end
end
