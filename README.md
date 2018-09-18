# Rabbit

## Docker ENV

```
docker run -d \
--hostname rabbit-dxx \
--name some-rabbit \
-e RABBITMQ_DEFAULT_USER=guest \
-e RABBITMQ_DEFAULT_PASS=guest \
-p 15672:15672 \
-p 5672:5672 \
rabbitmq:3-management
```

## Server
```
defmodule Rabbit.Server do
  use Linklab.Bunny.Consumer

  @impl true
  def setup(channel, %{exchange: exchange, queue: queue, topic: topic} = opts) do
    {:ok, _} = AMQP.Queue.declare(channel, "#{queue}_error", durable: true)
    {:ok, _} = AMQP.Queue.declare(channel, queue,
                             durable: true,
                             arguments: [
                               {"x-dead-letter-exchange", :longstr, ""},
                               {"x-dead-letter-routing-key", :longstr, "#{queue}_error"}])
    IO.inspect("Server #{topic}")

    :ok = AMQP.Exchange.topic(channel, exchange, durable: true)
    :ok = AMQP.Queue.bind(channel, queue, exchange, routing_key: topic)

    # Limit unacknowledged messages
    :ok = AMQP.Basic.qos(channel, prefetch_count: Map.get(opts, :prefetch_count, 10))

    # Register the GenServer process as a consumer
    {:ok, consumer_tag} = AMQP.Basic.consume(channel, queue, self())

    {:ok, Map.put(opts, :consumer_tag, consumer_tag)}
  end

  @impl true
  def basic_deliver(channel, _opts, payload, %{delivery_tag: tag, redelivered: redelivered}) do
    number = String.to_integer(payload)
    if number <= 10 do
      :ok = AMQP.Basic.ack(channel, tag)
      IO.puts "Consumed a #{number}."
    else
      :ok = AMQP.Basic.reject(channel, tag, requeue: false)
      IO.puts "#{number} is too big and was rejected."
    end

  rescue
    _ ->
      :ok = AMQP.Basic.reject(channel, tag, requeue: not redelivered)
      IO.puts "Error converting #{payload} to integer"
  end
end

# defmodule Rabbit.Client do
#   use Bunny.Consumer

#   @impl true
#   def setup(channel, %{exchange: exchange, queue: queue, topic: topic} = opts) do
#     IO.inspect("Client #{topic}")
#     {:ok, _} = AMQP.Queue.declare(channel, "#{queue}_error", durable: true)
#     {:ok, _} = AMQP.Queue.declare(channel, queue,
#                                                  durable: true,
#                                                  arguments: [
#                                                    {"x-dead-letter-exchange", :longstr, ""},
#                                                    {"x-dead-letter-routing-key", :longstr, "#{queue}_error"}])

#     :ok = AMQP.Exchange.topic(channel, exchange, durable: true)
#     :ok = AMQP.Queue.bind(channel, queue, exchange, routing_key: topic)

#     # Limit unacknowledged messages to 10
#     # :ok = AMQP.Basic.qos(channel, prefetch_count: Map.get(opts, :prefetch_count, 10))

#     # Register the GenServer process as a return handler
#     :ok = AMQP.Basic.return(channel, self())

#     {:ok, opts}
#   end
# end

defmodule Rabbit.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      {Linklab.Bunny.Pool, [
        %{
          name: :server,
          host: "localhost",
          username: "guest",
          password: "guest",
          heartbeat: 30,
          channel_size: 1,
          channel_overflow: 0,

          exchange: "testing_exchange",
          topic: "testing_topic",

          queue: "testing_queue",
          handler: Rabbit.Server,
          prefetch_count: 10,
        },
        %{
          name: :client,
          host: "localhost",
          username: "guest",
          password: "guest",
          heartbeat: 30,
          channel_size: 10,
          channel_overflow: 0,

          exchange: "testing_exchange",
          topic: "testing_topic",

          # queue: "testing_queue",
          # handler: Rabbit.Client,
        }
      ]}
    ]

    opts = [strategy: :one_for_one, name: Rabbit.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```