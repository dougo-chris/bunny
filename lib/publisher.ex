defmodule BunnyRabbit.Publisher do
  @moduledoc false

  alias AMQP.Basic, as: AMQPBasic
  alias BunnyRabbit.Pool, as: BunnyRabbitPool

  @spec publish(atom, any, list) :: :ok | AMQP.Basic.error()
  def publish(channel_name, payload, options \\ []) do
    BunnyRabbitPool.with_channel(channel_name, fn
      channel, %{exchange: exchange, topic: topic} ->
        AMQPBasic.publish(channel, exchange, topic, payload, options)

      channel, %{exchange: exchange} ->
        AMQPBasic.publish(channel, exchange, "", payload, options)
    end)
  end

  def retry(channel_name, payload, options \\ []) do
    BunnyRabbitPool.with_channel(channel_name, fn
      channel, %{exchange: exchange, topic: topic} ->
        AMQP.Basic.publish(channel, exchange, "#{topic}-retry", payload, options)

      channel, %{exchange: exchange} ->
        AMQPBasic.publish(channel, exchange, "retry", payload, options)
    end)
  end
end
