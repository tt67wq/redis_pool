defmodule RedisPool.Test.Integration.StandaloneApp do
  @moduledoc """
  用于测试单节点 Redis 连接的测试应用模块。
  此模块用于集成测试中测试与单个 Redis 实例的连接情况。
  """

  use RedisPool, otp_app: :redis_pool_xyz

  def init(config) do
    # 可以在这里添加自定义配置处理逻辑
    config
  end

  @doc """
  清理测试数据
  """
  def clean_test_data do
    command(["FLUSHDB"])
  end

  @doc """
  设置一个带有过期时间的键值对
  """
  def set_key_with_expiry(key, value, expiry_seconds) do
    command(["SET", key, value, "EX", to_string(expiry_seconds)])
  end

  @doc """
  执行事务操作
  """
  def transaction(commands) do
    pipeline([["MULTI"]] ++ commands ++ [["EXEC"]])
  end

  @doc """
  执行批量设置操作
  """
  def batch_set(key_values) do
    commands =
      Enum.map(key_values, fn {key, value} ->
        ["SET", key, value]
      end)

    pipeline(commands)
  end

  @doc """
  执行批量获取操作
  """
  def batch_get(keys) do
    commands =
      Enum.map(keys, fn key ->
        ["GET", key]
      end)

    case pipeline(commands) do
      {:ok, values} ->
        {:ok, keys |> Enum.zip(values) |> Map.new()}

      error ->
        error
    end
  end

  @doc """
  测试连接的健康状态
  """
  def health_check do
    command(["PING"])
  end
end
