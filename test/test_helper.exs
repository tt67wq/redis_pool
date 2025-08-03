# 启用异步测试
ExUnit.start(capture_log: true)

# 定义测试标记
ExUnit.configure(
  exclude: [
    # 跳过需要特殊环境的测试
    network_simulation: true,
    # 跳过可能不稳定的测试
    unstable: true
  ]
)

# 可选：检查测试环境是否已就绪
if System.get_env("CHECK_REDIS_ENV") == "true" do
  case RedisPool.Test.Integration.TestHelper.check_environment() do
    :ok ->
      IO.puts("Redis 测试环境已就绪")

    {:error, reason} ->
      IO.puts("警告: Redis 测试环境未就绪 - #{reason}")
      IO.puts("一些集成测试可能会失败，请确保已运行 test/docker/setup_test_env.sh start")
  end
end
