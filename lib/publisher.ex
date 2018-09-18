defmodule Linklab.Bunny.Publisher do

  @spec publish(atom, any, list) :: :ok | AMQP.Basic.error
  def publish(name, payload, options \\ []) do
    Linklab.Bunny.Pool.with_channel(name, fn
      channel, %{exchange: exchange, topic: topic} ->
        AMQP.Basic.publish(channel, exchange, topic, payload, options)
      channel, %{exchange: exchange} ->
        AMQP.Basic.publish(channel, exchange, "", payload, options)
    end)
  end
end
