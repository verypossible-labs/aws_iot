defmodule AWSIoT.Adapters.Tortoise.Handler do
  use Tortoise.Handler

  require Logger

  def init(args) do
    {:ok, args}
  end

  def connection(status, state) do
    # `status` will be either `:up` or `:down`; you can use this to
    # inform the rest of your system if the connection is currently
    # open or closed; tortoise should be busy reconnecting if you get
    # a `:down`
    Logger.debug "[AWS] Connection: #{inspect status}"
    {:ok, state}
  end

  def handle_message(_topic, _payload, state) do
    # unhandled message! You will crash if you subscribe to something
    # and you don't have a 'catch all' matcher; crashing on unexpected
    # messages could be a strategy though.
    {:ok, state}
  end

  def subscription(_status, _topic_filter, state) do
    {:ok, state}
  end

  def terminate(_reason, _state) do
    # tortoise doesn't care about what you return from terminate/2,
    # that is in alignment with other behaviours that implement a
    # terminate-callback
    Logger.debug "[AWS] Connection: terminated"
    :ok
  end
end
