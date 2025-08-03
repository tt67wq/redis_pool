defmodule RedisPool.Core do
  @moduledoc """
  Redis连接池的核心实现模块。

  该模块实现了基于 NimblePool 的 Redis 连接池，负责管理连接的创建、维护和回收。
  模块提供了与 Redis 服务器通信的基本命令，包括单个命令执行和管道命令执行。

  此模块通常不会被直接使用，而是通过 `RedisPool` 模块提供的宏来使用。
  """

  @behaviour NimblePool

  alias RedisPool.Error

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

  @typedoc """
  连接池配置选项类型
  """
  @type pool_opts_t :: keyword(unquote(NimbleOptions.option_typespec(@pool_opts_schema)))

  @typedoc """
  Redis命令类型，表示为二进制字符串的列表
  """
  @type command_t :: [binary()]

  @typedoc """
  连接状态类型，表示Redis连接的当前状态
  """
  @type connection_state_t :: pid()

  @typedoc """
  Redis响应类型
  """
  @type redis_response_t :: term()

  @typedoc """
  Redis错误类型
  """
  @type redis_error_t :: term()

  @typedoc """
  命令选项类型
  """
  @type command_opts_t :: keyword()

  @doc """
  返回用于监督树的子进程规范。

  此函数用于生成连接池的监督树子进程规范，便于将连接池添加到应用程序的监督树中。

  ## 参数

  - `opts`: 连接池配置选项，必须包含 `:name` 字段

  ## 返回值

  返回一个符合监督树子进程规范的映射，包含 `:id` 和 `:start` 字段

  ## 示例

      iex> opts = [name: MyRedis.Pool, url: "redis://:password@localhost:6379", pool_size: 5]
      iex> RedisPool.Core.child_spec(opts)
      %{id: {RedisPool.Core, MyRedis.Pool}, start: {RedisPool.Core, :start_link, [[name: MyRedis.Pool, url: "redis://:password@localhost:6379", pool_size: 5]]}}
  """
  @spec child_spec(pool_opts_t()) :: Supervisor.child_spec()
  def child_spec(opts) do
    name = Keyword.fetch!(opts, :name)
    %{id: {__MODULE__, name}, start: {__MODULE__, :start_link, [opts]}}
  end

  @doc """
  启动一个 Redis 连接池。

  此函数创建并启动一个新的 Redis 连接池，使用 NimblePool 作为底层实现。
  连接池创建后，将按照配置的大小预先创建若干连接，并在需要时自动管理这些连接。

  ## 参数

  - `opts`: 连接池配置选项，包括：
    - `:name` - 连接池名称 (必需)
    - `:url` - Redis 服务器 URL (必需)，格式为 "redis://:password@host:port/db"
    - `:pool_size` - 连接池大小，默认为 10

  ## 返回值

  - `{:ok, pid}` - 连接池成功启动，返回连接池进程 PID
  - `{:error, reason}` - 连接池启动失败，返回失败原因

  ## 示例

      iex> opts = [url: "redis://:123456@localhost:6379", pool_size: 10, name: :my_pool]
      iex> {:ok, pid} = RedisPool.Core.start_link(opts)
      iex> is_pid(pid)
      true

  ## 错误处理

  如果提供的选项无效或者无法连接到 Redis 服务器，将返回 `{:error, reason}` 元组。
  常见的错误原因包括：

  - 无效的 URL 格式
  - 无法连接到指定的主机或端口
  - 认证失败
  - 连接超时
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

  @doc """
  停止指定的 Redis 连接池。

  此函数用于正常关闭连接池，它会优雅地关闭所有连接并释放相关资源。

  ## 参数

  - `name`: 连接池的名称或 PID

  ## 返回值

  - `:ok` - 连接池成功停止

  ## 示例

      iex> {:ok, _pid} = RedisPool.Core.start_link([url: "redis://localhost:6379", pool_size: 5, name: :test_pool])
      iex> RedisPool.Core.stop(:test_pool)
      :ok
  """
  @spec stop(pid() | atom()) :: :ok
  def stop(name) do
    NimblePool.stop(name)
  end

  @doc """
  执行 Redis 命令。

  此函数从连接池中获取一个连接，执行指定的 Redis 命令，然后将连接归还给连接池。
  它是 Redix.command/3 函数的包装，提供了连接池管理和错误处理功能。

  ## 参数

  - `name`: 连接池的名称或 PID
  - `command`: Redis 命令，表示为字符串列表，例如 `["SET", "key", "value"]`
  - `opts`: 命令选项，包括：
    - `:pool_timeout` - 获取连接的超时时间（毫秒），默认为 5000
    - `:retry_count` - 命令执行失败时的重试次数，默认为 0
    - 其他选项将传递给 Redix.command/3

  ## 返回值

  - `{:ok, result}` - 命令执行成功，返回命令结果
  - `{:error, error}` - 命令执行失败，返回错误信息

  ## 示例

      iex> RedisPool.Core.command(pool, ["SET", "foo", "bar"])
      {:ok, "OK"}

      iex> RedisPool.Core.command(pool, ["GET", "foo"])
      {:ok, "bar"}

      iex> RedisPool.Core.command(pool, ["INCR", "counter"])
      {:ok, 1}

      iex> RedisPool.Core.command(pool, ["KEYS", "f*"])
      {:ok, ["foo"]}

  ## 错误处理

  可能返回的错误包括：

  - 连接池超时 - 无法在指定时间内获取连接
  - 连接错误 - 执行命令时连接断开
  - 命令错误 - Redis 服务器返回错误
  - 超时错误 - 命令执行超时
  """
  @spec command(pid() | atom(), command_t(), command_opts_t()) ::
          {:ok, redis_response_t()} | {:error, Error.t()}
  def command(name, command, opts \\ [])

  def command(name, command, opts) do
    {pool_timeout, opts} = Keyword.pop(opts, :pool_timeout, 5000)
    {retry_count, opts} = Keyword.pop(opts, :retry_count, 0)

    try do
      NimblePool.checkout!(
        name,
        :checkout,
        fn _, conn ->
          result =
            conn
            |> Redix.command(command, opts)
            |> handle_command_result(command)

          {result, conn}
        end,
        pool_timeout
      )
    rescue
      e in RuntimeError ->
        if is_binary(e.message) and String.contains?(e.message, "checkout timeout") do
          {:error, Error.timeout_error("连接池获取连接超时", {pool_timeout, e})}
        else
          retry_or_error(e, retry_count, fn ->
            command(name, command, Keyword.put(opts, :retry_count, retry_count - 1))
          end)
        end

      e ->
        retry_or_error(e, retry_count, fn -> command(name, command, Keyword.put(opts, :retry_count, retry_count - 1)) end)
    catch
      :exit, reason ->
        {:error, Error.connection_error("执行命令时连接异常退出", reason)}
    end
  end

  # 处理命令执行结果
  defp handle_command_result({:ok, result}, _command), do: {:ok, result}

  defp handle_command_result({:error, reason}, command) do
    _error_message = "执行命令 #{inspect(command)} 失败"
    {:error, Error.from_redix_error({:error, reason})}
  end

  # 处理重试逻辑
  defp retry_or_error(_error, retry_count, retry_fun) when retry_count > 0 do
    # 可以在这里添加重试延迟逻辑
    retry_fun.()
  end

  defp retry_or_error(error, _retry_count, _retry_fun) do
    case error do
      %Error{} = e -> {:error, e}
      _ -> {:error, Error.unknown_error("执行命令时发生未知错误", error)}
    end
  end

  @doc """
  执行 Redis 管道命令。

  此函数从连接池中获取一个连接，执行一系列 Redis 命令作为管道操作，然后将连接归还给连接池。
  管道操作可以显著提高多个命令执行的性能，因为它们在一个网络往返中发送和接收。
  它是 Redix.pipeline/3 函数的包装，提供了连接池管理和错误处理功能。

  ## 参数

  - `name`: 连接池的名称或 PID
  - `commands`: Redis 命令列表，每个命令表示为字符串列表，例如 `[["SET", "key1", "value1"], ["SET", "key2", "value2"]]`
  - `opts`: 命令选项，包括：
    - `:pool_timeout` - 获取连接的超时时间（毫秒），默认为 5000
    - `:retry_count` - 命令执行失败时的重试次数，默认为 0
    - 其他选项将传递给 Redix.pipeline/3

  ## 返回值

  - `{:ok, results}` - 管道命令执行成功，返回每个命令的结果列表
  - `{:error, error}` - 管道命令执行失败，返回错误信息

  ## 示例

      iex> RedisPool.Core.pipeline(pool, [["SET", "foo", "bar"], ["SET", "bar", "foo"]])
      {:ok, ["OK", "OK"]}

      iex> RedisPool.Core.pipeline(pool, [["GET", "foo"], ["GET", "bar"]])
      {:ok, ["bar", "foo"]}

      iex> RedisPool.Core.pipeline(pool, [["INCR", "counter"], ["INCR", "counter"]])
      {:ok, [1, 2]}

  ## 错误处理

  可能返回的错误包括：

  - 连接池超时 - 无法在指定时间内获取连接
  - 连接错误 - 执行命令时连接断开
  - 命令错误 - Redis 服务器返回错误
  - 超时错误 - 命令执行超时
  """
  @spec pipeline(pid() | atom(), [command_t()], command_opts_t()) ::
          {:ok, [redis_response_t()]} | {:error, Error.t()}
  def pipeline(name, commands, opts \\ [])

  def pipeline(name, commands, opts) do
    {pool_timeout, opts} = Keyword.pop(opts, :pool_timeout, 5000)
    {retry_count, opts} = Keyword.pop(opts, :retry_count, 0)

    try do
      NimblePool.checkout!(
        name,
        :checkout,
        fn _, conn ->
          result =
            conn
            |> Redix.pipeline(commands, opts)
            |> handle_pipeline_result(commands)

          {result, conn}
        end,
        pool_timeout
      )
    rescue
      e in RuntimeError ->
        if is_binary(e.message) and String.contains?(e.message, "checkout timeout") do
          {:error, Error.timeout_error("连接池获取连接超时", {pool_timeout, e})}
        else
          retry_or_error(e, retry_count, fn ->
            pipeline(name, commands, Keyword.put(opts, :retry_count, retry_count - 1))
          end)
        end

      e ->
        retry_or_error(e, retry_count, fn ->
          pipeline(name, commands, Keyword.put(opts, :retry_count, retry_count - 1))
        end)
    catch
      :exit, reason ->
        {:error, Error.connection_error("执行管道命令时连接异常退出", reason)}
    end
  end

  # 处理管道命令执行结果
  defp handle_pipeline_result({:ok, results}, _commands), do: {:ok, results}

  defp handle_pipeline_result({:error, reason}, commands) do
    _error_message = "执行管道命令 #{inspect(commands)} 失败"
    {:error, Error.from_redix_error({:error, reason})}
  end

  @doc """
  NimblePool 回调函数：初始化工作进程。

  此函数在创建新的连接池工作进程时被 NimblePool 调用。
  它负责创建到 Redis 服务器的新连接，并返回连接状态。

  ## 参数

  - `redis_url`: Redis 服务器的 URL

  ## 返回值

  - `{:ok, conn, pool_state}` - 连接成功创建
  - `{:error, error}` - 连接创建失败
  """
  @impl NimblePool
  @spec init_worker(String.t()) :: {:ok, connection_state_t(), String.t()} | {:error, Error.t()}
  def init_worker(pool_state = redis_url) do
    case Redix.start_link(redis_url) do
      {:ok, conn} ->
        {:ok, conn, pool_state}

      {:error, reason} ->
        error =
          case reason do
            :econnrefused ->
              Error.connection_error("Redis连接被拒绝，请检查主机和端口是否正确", reason)

            :nxdomain ->
              Error.connection_error("Redis域名无法解析，请检查主机名是否正确", reason)

            {:connection_error, redix_err} ->
              Error.connection_error("Redis连接失败", redix_err)

            :invalid_uri ->
              Error.connection_error("Redis URI格式无效，请检查URL格式", reason)

            {:auth, _} ->
              Error.authentication_error("Redis认证失败，请检查密码是否正确", reason)

            other ->
              Error.connection_error("Redis连接失败", other)
          end

        {:error, error}
    end
  end

  @doc """
  NimblePool 回调函数：处理连接检出。

  此函数在从连接池检出连接时被 NimblePool 调用。
  它返回连接状态，以便客户端可以使用连接。

  ## 参数

  - `checkout_reason`: 检出原因，当前仅支持 `:checkout`
  - `from`: 请求连接的客户端进程信息
  - `conn`: 当前连接状态
  - `pool_state`: 连接池状态

  ## 返回值

  - `{:ok, checkout_result, conn, pool_state}` - 连接检出成功
  """
  @impl NimblePool
  @spec handle_checkout(:checkout, GenServer.from(), connection_state_t(), String.t()) ::
          {:ok, connection_state_t(), connection_state_t(), String.t()}
  def handle_checkout(:checkout, _from, conn, pool_state) do
    {:ok, conn, conn, pool_state}
  end

  @doc """
  NimblePool 回调函数：处理连接归还。

  此函数在连接归还到连接池时被 NimblePool 调用。
  它接受归还的连接，并更新连接池状态。

  ## 参数

  - `conn`: 要归还的连接状态
  - `_checkin_reason`: 归还原因（未使用）
  - `_old_conn`: 检出时的连接状态（未使用）
  - `pool_state`: 连接池状态

  ## 返回值

  - `{:ok, conn, pool_state}` - 连接归还成功
  """
  @impl NimblePool
  @spec handle_checkin(connection_state_t(), term(), connection_state_t(), String.t()) ::
          {:ok, connection_state_t(), String.t()}
  def handle_checkin(conn, _, _old_conn, pool_state) do
    {:ok, conn, pool_state}
  end

  @doc """
  NimblePool 回调函数：处理进程消息。

  此函数在连接池工作进程收到消息时被 NimblePool 调用。
  它处理特定的消息，如连接关闭请求。

  ## 参数

  - `message`: 收到的消息
  - `conn`: 当前连接状态

  ## 返回值

  - `{:remove, :closed}` - 连接应该被移除
  - `{:ok, conn}` - 连接应该保持活跃
  """
  @impl NimblePool
  @spec handle_info(:close | term(), connection_state_t()) ::
          {:remove, :closed} | {:ok, connection_state_t()}
  def handle_info(:close, _conn), do: {:remove, :closed}
  def handle_info(_, conn), do: {:ok, conn}

  @doc """
  NimblePool 回调函数：处理连接健康检查。

  此函数定期被 NimblePool 调用，用于检查连接的健康状态。
  它向 Redis 服务器发送 PING 命令，并根据响应决定连接是否健康。

  ## 参数

  - `conn`: 当前连接状态
  - `_pool_state`: 连接池状态

  ## 返回值

  - `{:ok, conn}` - 连接健康，可以继续使用
  - `{:remove, reason}` - 连接不健康，应该被移除，原因包括：
    - `:invalid_response` - 收到非预期的响应
    - `:connection_error` - 连接错误
    - `:timeout` - 健康检查超时
    - `:command_error` - 命令执行错误
    - `:exception` - 发生异常
    - `:connection_closed` - 连接已关闭
  """
  @impl NimblePool
  @spec handle_ping(connection_state_t(), String.t()) ::
          {:ok, connection_state_t()} | {:remove, :closed}
  def handle_ping(conn, _pool_state) do
    conn
    |> Redix.command(["PING"])
    |> case do
      {:ok, "PONG"} -> {:ok, conn}
      {:ok, _} -> {:remove, :invalid_response}
      {:error, %Redix.ConnectionError{}} -> {:remove, :connection_error}
      {:error, :timeout} -> {:remove, :timeout}
      {:error, _} -> {:remove, :command_error}
    end
  rescue
    _ -> {:remove, :exception}
  catch
    :exit, _ -> {:remove, :connection_closed}
  end

  @doc """
  NimblePool 回调函数：终止工作进程。

  此函数在连接池工作进程终止时被 NimblePool 调用。
  它负责优雅地关闭 Redis 连接并清理资源。

  ## 参数

  - `_reason`: 终止原因
  - `conn`: 当前连接状态
  - `pool_state`: 连接池状态

  ## 返回值

  - `{:ok, pool_state}` - 连接成功终止
  """
  @impl NimblePool
  @spec terminate_worker(term(), connection_state_t(), String.t()) ::
          {:ok, String.t()}
  def terminate_worker(_reason, conn, pool_state) do
    Redix.stop(conn)
    {:ok, pool_state}
  end
end
