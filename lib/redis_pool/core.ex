defmodule RedisPool.Core do
  @moduledoc false

  @behaviour NimblePool

  @pool_opts_schema [
    name: [
      type: :atom,
      required: true,
      doc: "The name of the pool"
    ],
    pool_size: [
      type: :non_neg_integer,
      default: 10,
      doc: "The size of the pool"
    ],
    url: [
      type: :string,
      required: true,
      doc: "The url of the redis server, like redis://:123456@localhost:6379"
    ]
  ]

  @type pool_opts_t :: keyword(unquote(NimbleOptions.option_typespec(@pool_opts_schema)))
  @type command_t :: [binary()]

  def child_spec(opts) do
    name = Keyword.fetch!(opts, :name)
    %{id: {__MODULE__, name}, start: {__MODULE__, :start_link, [opts]}}
  end

  @doc """
  start redis with nimble pool

  ## Examples

      iex> opts = [url: "redis://:123456@localhost:6379", pool_size: 10, name: :my_pool]
      iex> RedisPool.Core.start_link(opts)
  """
  @spec start_link(pool_opts_t()) :: GenServer.on_start()
  def start_link(opts) do
    opts = NimbleOptions.validate!(opts, @pool_opts_schema)

    NimblePool.start_link(
      worker: {__MODULE__, opts[:url]},
      pool_size: opts[:pool_size],
      worker_idle_timeout: 10_000,
      name: opts[:name]
    )
  end

  @spec stop(pid() | atom()) :: :ok
  def stop(name) do
    NimblePool.stop(name)
  end

  @doc """
  delegate to Redix.command/2

  ## Examples

      iex> RedisPool.Core.command(pool, ["SET", "foo", "bar"])
      {:ok, "OK"}
  """
  @spec command(pid() | atom(), command_t(), keyword()) ::
          {:ok, term()} | {:error, term()}
  def command(name, command, opts \\ [])

  def command(name, command, opts) do
    {pool_timeout, opts} = Keyword.pop(opts, :pool_timeout, 5000)

    NimblePool.checkout!(
      name,
      :checkout,
      fn _, conn ->
        conn
        |> Redix.command(command, opts)
        |> then(fn x -> {x, conn} end)
      end,
      pool_timeout
    )
  end

  @doc """
  delegate to Redix.pipeline/2

  ## Examples

      iex> RedisPool.Core.pipeline(pool, [["SET", "foo", "bar"], ["SET", "bar", "foo"]])
      {:ok, ["OK", "OK"]]}
  """
  @spec pipeline(pid() | atom(), [command_t()], keyword()) ::
          {:ok, term()} | {:error, term()}
  def pipeline(name, commands, opts \\ [])

  def pipeline(name, commands, opts) do
    {pool_timeout, opts} = Keyword.pop(opts, :pool_timeout, 5000)

    NimblePool.checkout!(
      name,
      :checkout,
      fn _, conn ->
        conn
        |> Redix.pipeline(commands, opts)
        |> then(fn x -> {x, conn} end)
      end,
      pool_timeout
    )
  end

  @impl NimblePool
  @spec init_worker(String.t()) :: {:ok, pid, any}
  def init_worker(redis_url = pool_state) do
    {:ok, conn} = Redix.start_link(redis_url)
    {:ok, conn, pool_state}
  end

  @impl NimblePool
  def handle_checkout(:checkout, _from, conn, pool_state) do
    {:ok, conn, conn, pool_state}
  end

  @impl NimblePool
  def handle_checkin(conn, _, _old_conn, pool_state) do
    {:ok, conn, pool_state}
  end

  @impl NimblePool
  def handle_info(:close, _conn), do: {:remove, :closed}
  def handle_info(_, conn), do: {:ok, conn}

  @impl NimblePool
  def handle_ping(conn, _pool_state) do
    conn
    |> Redix.command(["PING"])
    |> case do
      {:ok, "PONG"} -> {:ok, conn}
      _ -> {:remove, :closed}
    end
  end

  @impl NimblePool
  def terminate_worker(_reason, conn, pool_state) do
    Redix.stop(conn)
    {:ok, pool_state}
  end
end
