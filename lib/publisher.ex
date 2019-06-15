defmodule Linklab.Bunny.Publisher do
  @moduledoc false

  alias AMQP.Basic, as: AMQPBasic
  alias Linklab.Bunny.Pool, as: BunnyPool

  @spec publish(atom, String.t(), any, list) :: :ok | AMQP.Basic.error()
  def publish(channel_name, routing_key, payload, options \\ []) do
    BunnyPool.with_channel(channel_name, fn channel, %{exchange: exchange} ->
      AMQPBasic.publish(channel, exchange, routing_key, payload, options)
    end)
  end

  @spec publish(atom, any, list) :: :ok | AMQP.Basic.error()
  def publish(channel_name, payload, options \\ []) do
    BunnyPool.with_channel(channel_name, fn
      channel, %{exchange: exchange, topic: topic} ->
        AMQPBasic.publish(channel, exchange, topic, payload, options)

      channel, %{exchange: exchange} ->
        AMQPBasic.publish(channel, exchange, "", payload, options)
    end)
  end

  @spec retry(atom, any, list) :: :ok | AMQPBasic.error()
  def retry(channel_name, payload, options \\ []) do
    BunnyPool.with_channel(channel_name, fn
      channel, %{exchange: exchange, topic: topic} ->
        AMQPBasic.publish(channel, exchange, "#{topic}-retry", payload, options)

      channel, %{exchange: exchange} ->
        AMQPBasic.publish(channel, exchange, "retry", payload, options)
    end)
  end
end
