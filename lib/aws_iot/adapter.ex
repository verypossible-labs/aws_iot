defmodule CloudPubSub.Adapter do
  @moduledoc """
  A GenServer that manages interaction with an AWS IoT Core implementation.
  """

  use GenServer

  @callback connected?(adapter_state()) :: {boolean(), adapter_state()}
  @callback publish(topic, payload, publish_opts(), adapter_state()) ::
              {publish_opts(), adapter_state()}
  @callback subscribe(topic, subscribe_opts(), adapter_state()) :: {boolean(), adapter_state()}
  @default_adapter CloudPubSub.Adapters.Tortoise.SSL
  @type adapter_state() :: any()
  @type payload() :: String.t()
  @type publish_opts() :: keyword()
  @type publish_ret() :: :ok | {:error, any()}
  @type qos() :: {0..1}
  @type subscribe_opts() :: [{:qos, qos()}]
  @type subscription() :: {topic(), qos()}
  @type subscriptions() :: [subscription()]
  @type topic() :: String.t()
  @type opts() :: [
          host: String.t(),
          client_id: String.t(),
          signer_cert: String.t(),
          port: integer(),
          server_name_indication: String.t(),
          aws_ca_certs: [String.t()],
          signer_cert: String.t()
        ]
  @doc """
  Return whether there is an active connection to AWS IoT Core.
  """
  def connected?(), do: GenServer.call(__MODULE__, :connected?)

  @impl GenServer
  def handle_call(:connected?, _from, state) do
    {ret, adapter_state} = state.adapter.connected?(state.adapter_state)
    {:reply, ret, Map.put(state, :adapter_state, adapter_state)}
  end

  def handle_call({:publish, topic, payload, opts}, _from, state) do
    {ret, adapter_state} = state.adapter.publish(topic, payload, opts, state.adapter_state)
    {:reply, ret, Map.put(state, :adapter_state, adapter_state)}
  end

  def handle_call({:subscribe, topic, opts}, _from, state) do
    {ret, adapter_state} = state.adapter.subscribe(topic, opts, state.adapter_state)
    {:reply, ret, Map.put(state, :adapter_state, adapter_state)}
  end

  @impl GenServer
  def init(opts) do
    adapter = adapter()
    opts = default_opts(opts)

    case adapter.init(opts) do
      {:ok, adapter_state} ->
        {:ok, %{adapter: adapter, adapter_state: adapter_state}}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @doc """
  Attempt to publish to AWS IoT Core.
  """
  def publish(topic, payload, opts) do
    GenServer.call(__MODULE__, {:publish, topic, payload, opts})
  end

  @doc """
  Start an adapter implementation.

  ## Options

  `:aws_ca_certs` - `String.t()`. Optional. Defaults to all four ATS CAs. The AWS CA certificates
    to include during authentication.
  `:client_id` - `String.t()`. Required. The MQTT client ID to connect with.
  `:device_cert` - `String.t()`. Required. The client certificate.
  `:device_key` - `String.t()`. Required. The client key.
  `:host` - `String.t()`. Required. The MQTT endpoint to connect to. Typically your ATS endpoint.
  `:port` - `integer()`. Optional. Defaults to `443`. The MQTT port to connect to.
  `:server_name_indication` - `String.t()`. Optional. Defaults to `*.iot.us-east-1.amazonaws.com`.
    A client indication to the server of what server name it is attempting to connect to.
  `:signer_cert` - `String.t()`. Required. The certificate that signed your client certificate in
  `:subscriptions` - `t:subscriptions()`. Optional. A list of topics to subscribe to on connection.
  """
  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @doc """
  Attempt to subscribe to a topic.
  """
  def subscribe(topic, qos), do: GenServer.call(__MODULE__, {:subscribe, topic, qos})

  defp adapter, do: Application.get_env(:cloud_pub_sub, :adapter, @default_adapter)

  defp default_opts(opts) do
    opts[:host] || raise "AWS IoT requires a :host."
    opts[:client_id] || raise "AWS IoT requires a :client_id."

    opts
    |> Keyword.put_new(:port, 443)
    |> Keyword.put_new(:server_name_indication, "*.iot.us-east-1.amazonaws.com")
    |> Keyword.put_new(:aws_ca_certs, CloudPubSub.cacerts())
    |> Keyword.put_new(:subscriptions, [])
  end
end
