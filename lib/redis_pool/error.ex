defmodule RedisPool.Error do
  @moduledoc """
  定义 RedisPool 库中使用的错误类型和错误处理函数。

  本模块提供了统一的错误类型定义和错误处理机制，使得整个库中的错误处理更加一致和可预测。
  通过使用统一的错误结构，可以更容易地区分不同类型的错误，并提供更详细的错误信息。

  错误类型包括：
  - `:connection_error` - 连接相关错误
  - `:command_error` - 命令执行错误
  - `:timeout_error` - 超时错误
  - `:network_error` - 网络错误
  - `:authentication_error` - 认证错误
  - `:pool_error` - 连接池错误
  - `:unknown_error` - 未知错误

  此模块同时提供了错误处理辅助函数，用于转换和规范化错误。
  """

  @typedoc """
  基本错误类型，包含错误码、错误消息和原因

  ## 字段

  - `code`: 错误类型代码，用于分类错误
  - `message`: 人类可读的错误消息
  - `reason`: 底层错误原因，可以是任何类型
  """
  @type t :: %__MODULE__{
          code: error_code_t(),
          message: String.t(),
          reason: term()
        }

  @typedoc """
  错误码类型，用于标识不同类型的错误

  ## 值

  - `:connection_error` - 与 Redis 连接相关的错误
  - `:command_error` - Redis 命令执行错误
  - `:timeout_error` - 操作超时错误
  - `:network_error` - 网络通信错误
  - `:authentication_error` - Redis 认证失败错误
  - `:pool_error` - 连接池管理错误
  - `:unknown_error` - 未分类的未知错误
  """
  @type error_code_t ::
          :connection_error
          | :command_error
          | :timeout_error
          | :network_error
          | :authentication_error
          | :pool_error
          | :unknown_error

  defexception [:code, :message, :reason]

  @doc """
  实现 Exception 协议的 message/1 函数，返回格式化的错误消息。

  此函数将错误的代码、消息和原因组合成一个格式化的字符串，便于日志记录和错误报告。

  ## 参数

  - `error`: RedisPool.Error 结构体

  ## 返回值

  返回格式化的错误消息字符串

  ## 示例

      iex> error = %RedisPool.Error{code: :connection_error, message: "连接失败", reason: :timeout}
      iex> RedisPool.Error.message(error)
      "RedisPool错误 [connection_error]: 连接失败, 原因: :timeout"
  """
  @spec message(t()) :: String.t()
  def message(%__MODULE__{code: code, message: message, reason: reason}) do
    "RedisPool错误 [#{code}]: #{message}, 原因: #{inspect(reason)}"
  end

  @doc """
  创建连接错误。

  用于表示与 Redis 服务器建立或维护连接相关的错误。
  这可能包括无法连接到服务器、连接断开或连接超时等情况。

  ## 参数

  - `message`: 错误消息，描述连接错误的性质
  - `reason`: 错误原因，可以是任何与错误相关的额外信息，默认为 `nil`

  ## 返回值

  返回一个格式化的 RedisPool.Error 结构体

  ## 示例

      iex> RedisPool.Error.connection_error("无法连接到 Redis 服务器", :econnrefused)
      %RedisPool.Error{code: :connection_error, message: "无法连接到 Redis 服务器", reason: :econnrefused}
  """
  @spec connection_error(String.t(), term()) :: t()
  def connection_error(message, reason \\ nil) do
    %__MODULE__{
      code: :connection_error,
      message: message,
      reason: reason
    }
  end

  @doc """
  创建命令执行错误。

  用于表示 Redis 命令执行过程中发生的错误。
  这可能包括无效的命令语法、参数错误或 Redis 服务器返回的错误响应。

  ## 参数

  - `message`: 错误消息，描述命令错误的性质
  - `reason`: 错误原因，可以是 Redis 服务器返回的错误信息或其他相关数据，默认为 `nil`

  ## 返回值

  返回一个格式化的 RedisPool.Error 结构体

  ## 示例

      iex> RedisPool.Error.command_error("HSET 命令参数不足", "ERR wrong number of arguments for 'hset' command")
      %RedisPool.Error{code: :command_error, message: "HSET 命令参数不足", reason: "ERR wrong number of arguments for 'hset' command"}
  """
  @spec command_error(String.t(), term()) :: t()
  def command_error(message, reason \\ nil) do
    %__MODULE__{
      code: :command_error,
      message: message,
      reason: reason
    }
  end

  @doc """
  创建超时错误。

  用于表示操作超时的情况。这可能发生在连接池获取连接超时、
  命令执行超时或网络通信超时等场景。

  ## 参数

  - `message`: 错误消息，描述超时错误的性质
  - `reason`: 错误原因，可以包含超时时间或其他相关信息，默认为 `nil`

  ## 返回值

  返回一个格式化的 RedisPool.Error 结构体

  ## 示例

      iex> RedisPool.Error.timeout_error("执行 BLPOP 命令超时", {:timeout, 5000})
      %RedisPool.Error{code: :timeout_error, message: "执行 BLPOP 命令超时", reason: {:timeout, 5000}}
  """
  @spec timeout_error(String.t(), term()) :: t()
  def timeout_error(message, reason \\ nil) do
    %__MODULE__{
      code: :timeout_error,
      message: message,
      reason: reason
    }
  end

  @doc """
  创建网络错误。

  用于表示网络通信中发生的错误，如连接关闭、网络不可达、
  主机不可达等网络层面的问题。

  ## 参数

  - `message`: 错误消息，描述网络错误的性质
  - `reason`: 错误原因，可以是底层网络错误代码或其他相关信息，默认为 `nil`

  ## 返回值

  返回一个格式化的 RedisPool.Error 结构体

  ## 示例

      iex> RedisPool.Error.network_error("Redis 连接意外关闭", :closed)
      %RedisPool.Error{code: :network_error, message: "Redis 连接意外关闭", reason: :closed}

      iex> RedisPool.Error.network_error("网络不可达", :enetunreach)
      %RedisPool.Error{code: :network_error, message: "网络不可达", reason: :enetunreach}
  """
  @spec network_error(String.t(), term()) :: t()
  def network_error(message, reason \\ nil) do
    %__MODULE__{
      code: :network_error,
      message: message,
      reason: reason
    }
  end

  @doc """
  创建认证错误。

  用于表示 Redis 认证失败的情况，通常是由于提供了错误的密码
  或者认证机制不匹配导致的。

  ## 参数

  - `message`: 错误消息，描述认证错误的性质
  - `reason`: 错误原因，可以是 Redis 服务器返回的认证错误信息，默认为 `nil`

  ## 返回值

  返回一个格式化的 RedisPool.Error 结构体

  ## 示例

      iex> RedisPool.Error.authentication_error("Redis 认证失败", "ERR invalid password")
      %RedisPool.Error{code: :authentication_error, message: "Redis 认证失败", reason: "ERR invalid password"}
  """
  @spec authentication_error(String.t(), term()) :: t()
  def authentication_error(message, reason \\ nil) do
    %__MODULE__{
      code: :authentication_error,
      message: message,
      reason: reason
    }
  end

  @doc """
  创建连接池错误。

  用于表示连接池管理中发生的错误，如无法创建足够的连接、
  连接池已满、连接池配置错误等情况。

  ## 参数

  - `message`: 错误消息，描述连接池错误的性质
  - `reason`: 错误原因，可以是连接池相关的错误信息，默认为 `nil`

  ## 返回值

  返回一个格式化的 RedisPool.Error 结构体

  ## 示例

      iex> RedisPool.Error.pool_error("连接池已满", {:pool_full, 10})
      %RedisPool.Error{code: :pool_error, message: "连接池已满", reason: {:pool_full, 10}}
  """
  @spec pool_error(String.t(), term()) :: t()
  def pool_error(message, reason \\ nil) do
    %__MODULE__{
      code: :pool_error,
      message: message,
      reason: reason
    }
  end

  @doc """
  创建未知错误。

  用于表示无法归类到其他特定错误类型的情况。
  这是一个通用的错误类型，通常用作最后的错误处理手段。

  ## 参数

  - `message`: 错误消息，描述未知错误的性质
  - `reason`: 错误原因，可以是任何与错误相关的信息，默认为 `nil`

  ## 返回值

  返回一个格式化的 RedisPool.Error 结构体

  ## 示例

      iex> RedisPool.Error.unknown_error("意外的错误情况", {:strange_error, "未知原因"})
      %RedisPool.Error{code: :unknown_error, message: "意外的错误情况", reason: {:strange_error, "未知原因"}}
  """
  @spec unknown_error(String.t(), term()) :: t()
  def unknown_error(message, reason \\ nil) do
    %__MODULE__{
      code: :unknown_error,
      message: message,
      reason: reason
    }
  end

  @doc """
  将 Redix 错误转换为 RedisPool 错误。

  此函数用于将 Redix 库返回的错误转换为 RedisPool 的标准错误格式，
  确保整个应用程序中的错误处理一致性。

  ## 参数

  - `error`: Redix 错误，通常是 `{:error, reason}` 格式

  ## 返回值

  返回对应的 RedisPool.Error 结构体

  ## 示例

      iex> RedisPool.Error.from_redix_error({:error, %Redix.ConnectionError{reason: :closed}})
      %RedisPool.Error{code: :connection_error, message: "Redis连接错误", reason: :closed}

      iex> RedisPool.Error.from_redix_error({:error, %Redix.Error{message: "WRONGTYPE"}})
      %RedisPool.Error{code: :command_error, message: "Redis命令错误", reason: "WRONGTYPE"}

      iex> RedisPool.Error.from_redix_error({:error, :timeout})
      %RedisPool.Error{code: :timeout_error, message: "Redis操作超时", reason: :timeout}
  """
  @spec from_redix_error(term()) :: t()
  def from_redix_error({:error, reason}) do
    case reason do
      %Redix.ConnectionError{reason: conn_reason} ->
        connection_error("Redis连接错误", conn_reason)

      %Redix.Error{message: message} ->
        command_error("Redis命令错误", message)

      :timeout ->
        timeout_error("Redis操作超时", :timeout)

      {:timeout, _} ->
        timeout_error("Redis操作超时", reason)

      :closed ->
        network_error("Redis连接已关闭", :closed)

      :noproc ->
        connection_error("Redis连接进程不存在", :noproc)

      %_{} = struct_error ->
        unknown_error("Redis未知结构化错误", struct_error)

      other ->
        unknown_error("Redis未知错误", other)
    end
  end

  def from_redix_error(error) do
    unknown_error("非预期的Redis错误格式", error)
  end

  @doc """
  分类并转换通用错误为 RedisPool 错误。

  此函数是一个通用的错误转换工具，可以将各种格式的错误转换为标准的 RedisPool.Error 结构。
  它首先检查错误是否已经是 RedisPool.Error 结构，如果不是，则根据错误类型进行分类和转换。

  ## 参数

  - `error`: 一般错误，通常是 `{:error, reason}` 格式

  ## 返回值

  返回标准化的 RedisPool.Error 结构体

  ## 示例

      iex> RedisPool.Error.normalize_error({:error, :timeout})
      %RedisPool.Error{code: :timeout_error, message: "操作超时", reason: :timeout}

      iex> RedisPool.Error.normalize_error({:error, :econnrefused})
      %RedisPool.Error{code: :network_error, message: "连接被拒绝", reason: :econnrefused}

      iex> error = RedisPool.Error.connection_error("测试错误")
      iex> RedisPool.Error.normalize_error({:error, error}) == error
      true
  """
  @spec normalize_error(term()) :: t()
  def normalize_error({:error, reason}) do
    case reason do
      %__MODULE__{} = error ->
        error

      %Redix.ConnectionError{} ->
        from_redix_error({:error, reason})

      %Redix.Error{} ->
        from_redix_error({:error, reason})

      :timeout ->
        timeout_error("操作超时", :timeout)

      {:timeout, details} ->
        timeout_error("操作超时", details)

      :closed ->
        network_error("连接已关闭", :closed)

      :noproc ->
        connection_error("进程不存在", :noproc)

      :econnrefused ->
        network_error("连接被拒绝", :econnrefused)

      :ehostunreach ->
        network_error("无法访问主机", :ehostunreach)

      :enetunreach ->
        network_error("网络不可达", :enetunreach)

      :unauthorized ->
        authentication_error("认证失败", :unauthorized)

      {:EXIT, pid, reason} when is_pid(pid) ->
        connection_error("连接进程异常退出", {:EXIT, pid, reason})

      other ->
        unknown_error("未知错误", other)
    end
  end

  def normalize_error(error) do
    unknown_error("非预期的错误格式", error)
  end

  @doc """
  包装函数调用，捕获并转换错误。

  此函数是一个高阶函数，用于包装其他函数调用，自动处理可能发生的各种错误。
  它捕获异常和退出信号，将它们转换为标准的 RedisPool.Error 结构，
  确保函数调用总是返回一致的成功或错误格式。

  ## 参数

  - `fun`: 要执行的函数，一个无参数的函数

  ## 返回值

  - `{:ok, result}` - 函数执行成功，返回函数的结果
  - `{:error, %RedisPool.Error{}}` - 函数执行失败，返回标准化的错误结构

  ## 示例

      iex> RedisPool.Error.wrap(fn -> {:ok, "success"} end)
      {:ok, "success"}

      iex> RedisPool.Error.wrap(fn -> {:error, :timeout} end)
      {:error, %RedisPool.Error{code: :timeout_error, message: "操作超时", reason: :timeout}}

      iex> RedisPool.Error.wrap(fn -> raise "测试异常" end)
      {:error, %RedisPool.Error{code: :unknown_error, message: "执行过程中发生异常", reason: %RuntimeError{message: "测试异常"}}}
  """
  @spec wrap((-> any())) :: {:ok, any()} | {:error, t()}
  def wrap(fun) do
    case fun.() do
      {:ok, result} -> {:ok, result}
      {:error, _} = error -> {:error, normalize_error(error)}
      other -> {:ok, other}
    end
  rescue
    e in [RedisPool.Error] -> {:error, e}
    e -> {:error, unknown_error("执行过程中发生异常", e)}
  catch
    :exit, reason -> {:error, connection_error("连接进程异常退出", reason)}
    error_type, error_value -> {:error, unknown_error("捕获到未处理的错误", {error_type, error_value})}
  end
end
