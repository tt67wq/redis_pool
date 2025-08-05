<!-- MDOC !-->
# RedisPool

一个基于 NimblePool 的 Redis 连接池库。

## 安装

将 `redis_pool_xyz` 添加到您的 `mix.exs` 依赖项中:

```elixir
def deps do
  [
    {:redis_pool_xyz, "~> 0.3"}
  ]
end
```

查看完整文档: [HexDocs](https://hexdocs.pm/redis_pool_xyz)

## 快速开始

### 基本用法

1. 添加一个使用 `RedisPool` 的模块:
   ```elixir
   defmodule MyApp.Redis do
     use RedisPool, otp_app: :my_app
   end
   ```

2. 配置 Redis 连接参数:
   ```elixir
   # 在 config/config.exs 中
   config :my_app, MyApp.Redis,
     url: "redis://:password@localhost:6379/0",
     pool_size: 10
   ```

   或者在运行时配置:
   ```elixir
   # 在应用程序中
   url = "redis://localhost:6379"
   config = [url: url, pool_size: 5]
   config :my_app, MyApp.Redis, config
   ```

3. 将 Redis 模块添加到应用程序的监督树中:
   ```elixir
   # 在应用程序的 supervisor 中
   children = [
     MyApp.Redis
   ]

   Supervisor.start_link(children, strategy: :one_for_one)
   ```

4. 使用定义的模块执行 Redis 命令:
   ```elixir
   # 执行单个命令
   {:ok, nil} = MyApp.Redis.command(["GET", "foo"])
   {:ok, "OK"} = MyApp.Redis.command(["SET", "foo", "bar"])
   {:ok, "bar"} = MyApp.Redis.command(["GET", "foo"])

   # 执行管道命令
   {:ok, ["OK", "OK"]} = MyApp.Redis.pipeline([
     ["SET", "foo1", "bar1"],
     ["SET", "foo2", "bar2"]
   ])
   ```

### 高级用法

#### 自定义初始化

您可以重写 `init/1` 函数来添加自定义配置处理逻辑:

```elixir
defmodule MyApp.Redis do
  use RedisPool, otp_app: :my_app

  @impl true
  def init(config) do
    # 添加默认配置
    config = Keyword.put_new(config, :pool_size, 5)

    # 添加日志
    require Logger
    Logger.info("初始化 Redis 连接池: #{inspect(config)}")

    # 验证配置
    if config[:url] do
      {:ok, config}
    else
      {:error, "Redis URL 未配置"}
    end
  end
end
```

#### 错误处理

所有命令执行都会返回 `{:ok, result}` 或 `{:error, error}` 元组。错误结构提供了详细的错误信息:

```elixir
# 处理可能的错误情况
case MyApp.Redis.command(["GET", "key"]) do
  {:ok, value} ->
    # 处理成功的结果
    IO.puts("值: #{value || "nil"}")

  {:error, %RedisPool.Error{code: :connection_error}} ->
    # 处理连接错误
    IO.puts("Redis 连接错误，请检查连接参数")

  {:error, %RedisPool.Error{code: :timeout_error}} ->
    # 处理超时错误
    IO.puts("Redis 操作超时")

  {:error, error} ->
    # 处理其他错误
    IO.puts("发生错误: #{inspect(error)}")
end
```

#### 配置选项

可用的连接池配置选项:

| 选项 | 类型 | 默认值 | 描述 |
|------|------|--------|------|
| `:url` | `String.t()` | 必需 | Redis 服务器 URL，格式为 "redis://:password@host:port/db" |
| `:pool_size` | `non_neg_integer()` | `10` | 连接池大小 |
| `:name` | `atom()` | 自动生成 | 连接池名称 |

命令执行选项:

| 选项 | 类型 | 默认值 | 描述 |
|------|------|--------|------|
| `:pool_timeout` | `non_neg_integer()` | `5000` | 获取连接的超时时间（毫秒） |
| `:retry_count` | `non_neg_integer()` | `0` | 命令执行失败时的重试次数 |

## 性能考虑

- 对于需要执行多个命令的场景，使用 `pipeline/2` 可以显著提高性能
- 适当配置连接池大小以匹配应用程序的并发需求
- 避免长时间占用连接，及时释放连接回连接池

## 贡献

欢迎贡献代码、报告问题或提出改进建议。请在 [GitHub Issues](https://github.com/tt67wq/redis_pool/issues) 上提交问题。

## 许可证

本项目基于 MIT 许可证开源。详见 [LICENSE](LICENSE) 文件。
