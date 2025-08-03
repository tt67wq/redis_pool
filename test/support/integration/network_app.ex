defmodule RedisPool.Test.Integration.NetworkApp do
  @moduledoc """
  用于测试不同网络条件下 Redis 连接行为的测试应用模块。
  此模块用于集成测试中测试在各种网络条件（延迟、丢包等）下的连接行为。
  """

  use RedisPool, otp_app: :redis_pool_xyz

  def init(config) do
    # 可以在这里添加自定义配置处理逻辑
    {:ok, config}
  end

  @doc """
  清理测试数据
  """
  def clean_test_data do
    command(["FLUSHDB"])
  end

  @doc """
  测试基本连接
  """
  def test_connectivity do
    command(["PING"])
  end

  @doc """
  测试连续多次操作的可靠性
  """
  def test_reliability(key_prefix, operations_count, delay_ms \\ 0) do
    results =
      for i <- 1..operations_count do
        # 可选的操作间延迟
        if delay_ms > 0, do: :timer.sleep(delay_ms)

        key = "#{key_prefix}:#{i}"
        value = "value_#{i}"

        write_result = command(["SET", key, value])
        read_result = command(["GET", key])

        {i, write_result, read_result}
      end

    {:ok, results}
  end

  @doc """
  测试在高延迟环境下的超时行为
  """
  def test_timeout_behavior(key, value, timeout_ms) do
    # 设置较短的命令超时
    opts = [timeout: timeout_ms]

    # 尝试执行可能超时的操作
    command(["SET", key, value], opts)
  end

  @doc """
  测试管道命令在网络不稳定环境下的行为
  """
  def test_pipeline_in_unstable_network(key_prefix, commands_count, opts \\ []) do
    commands =
      for i <- 1..commands_count do
        ["SET", "#{key_prefix}:#{i}", "value_#{i}"]
      end

    pipeline(commands, opts)
  end

  @doc """
  测试重试机制
  """
  def test_retry_mechanism(key, value, retry_count) do
    # 使用重试选项
    opts = [retry_count: retry_count]

    # 尝试执行操作
    command(["SET", key, value], opts)
  end

  @doc """
  测试连接重置后的行为
  """
  def test_reconnection_behavior(key, value, attempts \\ 5, delay_ms \\ 1000) do
    results =
      for i <- 1..attempts do
        # 每次操作前等待一定时间
        :timer.sleep(delay_ms)

        # 执行操作
        result = command(["SET", "#{key}:#{i}", "#{value}:#{i}"])
        {i, result}
      end

    {:ok, results}
  end

  @doc """
  测试长时间操作（如阻塞命令）在网络不稳定环境下的行为
  """
  def test_blocking_command(timeout_seconds \\ 5) do
    # 使用 BLPOP 命令，这是一个阻塞命令，会等待直到有数据或超时
    # 我们使用一个可能不存在的键，让它超时
    command(["BLPOP", "non_existent_key", to_string(timeout_seconds)])
  end

  @doc """
  测试大数据传输
  """
  def test_large_data_transfer(key, data_size_kb) do
    # 创建指定大小的数据
    value = String.duplicate("x", data_size_kb * 1024)

    # 尝试存储大数据
    command(["SET", key, value])
  end

  @doc """
  测试连接健康检查
  """
  def health_check do
    command(["PING"])
  end

  @doc """
  测试批量操作的错误恢复
  """
  def test_batch_error_recovery(valid_keys, invalid_key) do
    # 创建包含有效和无效操作的批量命令
    valid_commands =
      Enum.map(valid_keys, fn key ->
        ["SET", key, "value"]
      end)

    # 添加一个会失败的命令（无效的命令）
    invalid_command = [["INVALID_COMMAND", invalid_key]]

    # 执行批量命令
    results = pipeline(valid_commands ++ invalid_command)

    # 尝试恢复（执行清理操作）
    cleanup_results =
      Enum.map(valid_keys, fn key ->
        command(["DEL", key])
      end)

    {results, cleanup_results}
  end
end
