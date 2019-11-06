defmodule BunnyRabbit.Consumer do
  @moduledoc false

  alias AMQP.Basic, as: AMQPBasic

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
      import BunnyRabbit.Consumer

      @behaviour BunnyRabbit.Consumer

      def setup(_, _config), do: :ok
      def basic_deliver(_, _, _), do: :ok
      def basic_return(_, _, _), do: :ok
      def basic_consume_ok(_, _), do: :ok
      def basic_cancel(_, _), do: :ok
      def basic_cancel_ok(_, _), do: :ok

      defoverridable BunnyRabbit.Consumer
    end
  end

  def ack(channel, tag) do
    AMQPBasic.ack(channel, tag)
  end

  def reject(channel, tag, options) do
    AMQPBasic.reject(channel, tag, options)
  end
end
