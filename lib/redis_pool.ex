defmodule RedisPool do
  @moduledoc """
  RedisPool 是一个基于 NimblePool 的 Redis 连接池库。

  此模块提供了使用宏的方式创建 Redis 连接池，并提供了简单直观的 API 来执行 Redis 命令。
  主要特点包括：

  - 基于 NimblePool 的高效连接池管理
  - 简单的配置和使用方式
  - 支持单个命令和管道命令执行
  - 详细的错误处理和报告
  - 支持连接健康检查和自动恢复

  ## 基本用法

  1. 首先，定义一个使用 RedisPool 的模块：

      ```elixir
      defmodule MyApp.Redis do
        use RedisPool, otp_app: :my_app
      end
      ```

  2. 配置 Redis 连接参数（在配置文件或运行时）：

      ```elixir
      # 在 config/config.exs 中
      config :my_app, MyApp.Redis,
        url: "redis://:password@localhost:6379/0",
        pool_size: 10
      ```

  3. 将 Redis 模块添加到应用程序的监督树中：

      ```elixir
      # 在应用程序的 Supervisor 中
      children = [
        MyApp.Redis
      ]

      Supervisor.start_link(children, strategy: :one_for_one)
      ```

  4. 使用定义的模块执行 Redis 命令：

      ```elixir
      # 执行单个命令
      {:ok, "OK"} = MyApp.Redis.command(["SET", "key", "value"])
      {:ok, "value"} = MyApp.Redis.command(["GET", "key"])

      # 执行管道命令
      {:ok, ["OK", "OK"]} = MyApp.Redis.pipeline([
        ["SET", "key1", "value1"],
        ["SET", "key2", "value2"]
      ])
      ```

  ## 错误处理

  所有命令执行都会返回 `{:ok, result}` 或 `{:error, error}` 元组。
  错误结构提供了详细的错误信息，包括错误类型、消息和原因，便于调试和处理。
  """

  @external_resource "README.md"

  @typedoc """
  应用配置选项类型
  """
  @type config_t :: keyword()

  @typedoc """
  子进程规范类型
  """
  @type child_spec_t :: Supervisor.child_spec()

  @typedoc """
  OTP应用名类型
  """
  @type otp_app_t :: atom()
  defmacro __using__(opts) do
    quote do
      alias RedisPool.Core

      @doc """
      初始化连接池配置

      ## 参数

      - `config`: 连接池配置选项

      ## 返回值

      返回 `{:ok, config}` 元组
      """
      @spec init(RedisPool.config_t()) :: {:ok, RedisPool.config_t()} | {:error, RedisPool.Error.t()}
      @doc """
      初始化连接池配置。

      此函数在启动连接池之前被调用，允许对配置进行修改或验证。
      您可以重写此函数来添加自定义配置处理逻辑。

      ## 参数

      - `config`: 从应用程序配置或直接传递的配置选项

      ## 返回值

      - `{:ok, config}`: 配置有效，返回可能修改过的配置
      - `{:error, error}`: 配置无效，返回错误信息

      ## 示例

      ```elixir
      defmodule MyApp.Redis do
        use RedisPool, otp_app: :my_app

        @impl true
        def init(config) do
          # 添加默认配置
          config = Keyword.put_new(config, :pool_size, 5)

          # 验证配置
          if config[:url] do
            {:ok, config}
          else
            {:error, "Redis URL 未配置"}
          end
        end
      end
      ```
      """
      def init(config) do
        {:ok, config}
      end

      defoverridable init: 1

      @name Module.concat(__MODULE__, Core)

      @doc """
      返回用于监督树的子进程规范。

      此函数生成一个标准的子进程规范，使得模块可以直接添加到应用程序的监督树中。

      ## 参数

      - `opts`: 连接池配置选项

      ## 返回值

      返回一个符合监督树子进程规范的映射
      """
      @spec child_spec(keyword()) :: RedisPool.child_spec_t()
      def child_spec(opts) do
        %{
          id: __MODULE__,
          start: {__MODULE__, :start_link, [opts]}
        }
      end

      @doc """
      启动连接池

      ## 参数

      - `config`: 连接池配置选项，默认为空列表

      ## 返回值

      返回 `{:ok, pid}` 或 `{:error, reason}` 元组
      """
      @spec start_link(RedisPool.config_t()) :: GenServer.on_start() | {:error, RedisPool.Error.t()}
      def start_link(config \\ []) do
        otp_app = unquote(opts[:otp_app])

        case otp_app
             |> Application.get_env(__MODULE__, config)
             |> init() do
          {:ok, cfg} ->
            cfg
            |> Keyword.put(:name, @name)
            |> Core.start_link()

          {:error, _} = error ->
            error
        end
      end

      @doc """
      返回当前模块的核心连接池名称。

      此函数返回内部使用的连接池名称，通常用于调试和监控目的。

      ## 返回值

      返回表示连接池名称的原子

      ## 示例

      ```elixir
      iex> MyApp.Redis.pool_name()
      MyApp.Redis.Core
      ```
      """
      def pool_name, do: @name

      @doc false
      @spec delegate(atom(), list()) :: term()
      defp delegate(method, args), do: apply(Core, method, [@name | args])

      @doc """
      停止连接池。

      此函数优雅地关闭连接池，关闭所有连接并释放资源。
      通常在应用程序关闭时调用，或者在需要重新配置连接池时调用。

      ## 返回值

      - `:ok` - 连接池成功停止

      ## 示例

      ```elixir
      iex> MyApp.Redis.stop()
      :ok
      ```
      """
      @spec stop() :: :ok
      def stop, do: delegate(:stop, [])

      @doc """
      执行Redis命令。

      此函数从连接池中获取一个连接，执行指定的 Redis 命令，然后将连接归还给连接池。
      它支持所有标准的 Redis 命令。

      ## 参数

      - `command`: Redis命令，表示为二进制字符串的列表，例如 `["SET", "key", "value"]`
      - `opts`: 命令选项，包括：
        - `:pool_timeout` - 获取连接的超时时间（毫秒），默认为 5000
        - `:retry_count` - 命令执行失败时的重试次数，默认为 0
        - 其他选项将传递给 Redix

      ## 返回值

      - `{:ok, result}` - 命令执行成功，返回命令结果
      - `{:error, error}` - 命令执行失败，返回错误信息

      ## 示例

      ```elixir
      # 设置键值
      iex> MyApp.Redis.command(["SET", "user:1", "John"])
      {:ok, "OK"}

      # 获取键值
      iex> MyApp.Redis.command(["GET", "user:1"])
      {:ok, "John"}

      # 使用哈希表
      iex> MyApp.Redis.command(["HSET", "user:2", "name", "Jane", "age", "28"])
      {:ok, 2}
      iex> MyApp.Redis.command(["HGETALL", "user:2"])
      {:ok, ["name", "Jane", "age", "28"]}

      # 设置过期时间
      iex> MyApp.Redis.command(["SET", "session:123", "data", "EX", "3600"])
      {:ok, "OK"}

      # 处理不存在的键
      iex> MyApp.Redis.command(["GET", "nonexistent"])
      {:ok, nil}
      ```

      ## 错误处理

      ```elixir
      # 处理语法错误
      iex> MyApp.Redis.command(["INVALID"])
      {:error, %RedisPool.Error{code: :command_error, message: "Redis命令错误", reason: "ERR unknown command `INVALID`"}}

      # 处理连接错误
      iex> MyApp.Redis.command(["GET", "key"], pool_timeout: 1)
      {:error, %RedisPool.Error{code: :timeout_error, message: "连接池获取连接超时", reason: {1, ...}}}
      ```
      """
      @spec command(RedisPool.Core.command_t(), RedisPool.Core.command_opts_t()) ::
              {:ok, RedisPool.Core.redis_response_t()} | {:error, RedisPool.Error.t()}
      def command(command, opts \\ []), do: delegate(:command, [command, opts])

      @doc """
      执行Redis管道命令。

      此函数从连接池中获取一个连接，执行一系列 Redis 命令作为管道操作，然后将连接归还给连接池。
      管道操作可以显著提高多个命令执行的性能，因为它们在一个网络往返中发送和接收。

      ## 参数

      - `commands`: Redis命令列表，每个命令表示为二进制字符串的列表，例如 `[["SET", "key1", "value1"], ["SET", "key2", "value2"]]`
      - `opts`: 命令选项，包括：
        - `:pool_timeout` - 获取连接的超时时间（毫秒），默认为 5000
        - `:retry_count` - 命令执行失败时的重试次数，默认为 0
        - 其他选项将传递给 Redix

      ## 返回值

      - `{:ok, results}` - 管道命令执行成功，返回每个命令的结果列表
      - `{:error, error}` - 管道命令执行失败，返回错误信息

      ## 示例

      ```elixir
      # 执行多个SET命令
      iex> MyApp.Redis.pipeline([
      ...>   ["SET", "key1", "value1"],
      ...>   ["SET", "key2", "value2"],
      ...>   ["SET", "key3", "value3"]
      ...> ])
      {:ok, ["OK", "OK", "OK"]}

      # 执行多个GET命令
      iex> MyApp.Redis.pipeline([
      ...>   ["GET", "key1"],
      ...>   ["GET", "key2"],
      ...>   ["GET", "key3"]
      ...> ])
      {:ok, ["value1", "value2", "value3"]}

      # 混合命令
      iex> MyApp.Redis.pipeline([
      ...>   ["SET", "counter", "1"],
      ...>   ["INCR", "counter"],
      ...>   ["INCR", "counter"],
      ...>   ["GET", "counter"]
      ...> ])
      {:ok, ["OK", 2, 3, "3"]}
      ```

      ## 性能考虑

      管道操作对于需要执行多个命令的场景性能显著优于单独执行每个命令，
      特别是在有网络延迟的情况下。推荐在批量操作中使用管道命令。
      """
      @spec pipeline([RedisPool.Core.command_t()], RedisPool.Core.command_opts_t()) ::
              {:ok, [RedisPool.Core.redis_response_t()]} | {:error, RedisPool.Error.t()}
      def pipeline(commands, opts \\ []), do: delegate(:pipeline, [commands, opts])
    end
  end
end
