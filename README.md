# Linklab.Rabbit

# DEVELOPMENT
```./bin/api_linklab clean```     To clean runtime dependencies

```./bin/api_linklab build```     To install the dependencies

```./bin/api_linklab upgrade```   To upgrade the dependencies

```./bin/api_linklab iex```       To run the elixir command line

```./bin/api_linklab mix```       To run a mix task

# TESTING

```./bin/api_linklab test```            Run the tests

```./bin/api_linklab test dialyzer```   Execute dialyzer

```./bin/api_linklab test watch```      Continuously run the tests

```./bin/api_linklab test dev```        Continuously run the dev tests

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
  def setup(channel, %{exchange: exchange, queue: queue, topic: topic, prefetch: prefetch} = opts) do
    {:ok, _} = AMQP.Queue.declare(channel, "#{queue}_error", durable: true)
    {:ok, _} = AMQP.Queue.declare(channel, queue,
                             durable: true,
                             arguments: [
                               {"x-dead-letter-exchange", :longstr, ""},
                               {"x-dead-letter-routing-key", :longstr, "#{queue}_error"}])

    :ok = AMQP.Exchange.topic(channel, exchange, durable: true)
    :ok = AMQP.Queue.bind(channel, queue, exchange, routing_key: topic)

    # Limit unacknowledged messages
    :ok = AMQP.Basic.qos(channel, prefetch_count: prefetch)

    # Register the GenServer process as a consumer
    {:ok, _consumer_tag} = AMQP.Basic.consume(channel, queue, self())

    :ok
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
#   def setup(channel, %{exchange: exchange, queue: queue, topic: topic, prefetch: prefetch}) do
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
#     # :ok = AMQP.Basic.qos(channel, prefetch_count: prefetch)
#     # Register the GenServer process as a return handler
#     :ok = AMQP.Basic.return(channel, self())
#     :ok
#   end
# end

defmodule Rabbit.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      {Linklab.Bunny.Pool, [
        [
          channel_name: :server,
          channel_size: 1,
          channel_overflow: 0,

          env: [
            host: "localhost",
            username: "guest",
            password: "guest",
            heartbeat: 30
          ],

          handler: Rabbit.Server,
          config: %{
            exchange: "testing_exchange",
            queue: "testing_queue",
            topic: "testing_topic",
            prefetch: 10
          }
        ],
        [
          channel_name: :client,
          channel_size: 10,
          channel_overflow: 0,

          env: %{
            host: "localhost",
            username: "guest",
            password: "guest",
            heartbeat: 30
          }

          # handler: Rabbit.Client,
          config: %{
            exchange: "testing_exchange",
            topic: "testing_topic",
            # queue: "testing_queue"
          }

        ]
      ]}
    ]

    opts = [strategy: :one_for_one, name: Rabbit.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```