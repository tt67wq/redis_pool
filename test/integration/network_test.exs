defmodule RedisPool.Integration.NetworkTest do
  @moduledoc """
  Redis 网络条件集成测试。
  测试 RedisPool 在不同网络条件下的行为表现。

  运行测试前需要启动测试环境：
  ```
  cd test/docker && ./setup_test_env.sh start
  ```
  """

  use ExUnit.Case, async: false

  alias RedisPool.Test.Integration.NetworkApp

  @normal_url "redis://:redis_password@localhost:6379"
  @delayed_url "redis://:redis_password@localhost:6384"
  @unstable_url "redis://:redis_password@localhost:6385"

  setup_all do
    # 确保测试环境已经启动
    # 在实际环境中，这里可能需要检查 Redis 服务是否可用

    # 返回测试中需要的数据
    %{
      normal_url: @normal_url,
      delayed_url: @delayed_url,
      unstable_url: @unstable_url
    }
  end

  setup context do
    # 为每个测试配置应用
    redis_url = context[:redis_url] || @normal_url
    pool_size = context[:pool_size] || 5
    config = [url: redis_url, pool_size: pool_size]
    Application.put_env(:redis_pool_xyz, RedisPool.Test.Integration.NetworkApp, config)

    # 启动应用
    start_supervised!(NetworkApp)

    # 清理测试数据
    NetworkApp.clean_test_data()

    :ok
  end

  describe "正常网络条件测试" do
    @describetag redis_url: @normal_url

    test "基本连接测试" do
      assert {:ok, "PONG"} = NetworkApp.test_connectivity()
    end

    test "操作可靠性测试" do
      {:ok, results} = NetworkApp.test_reliability("normal", 10)

      # 所有操作都应该成功
      assert Enum.all?(results, fn {_, write_result, read_result} ->
               match?({:ok, "OK"}, write_result) &&
                 match?({:ok, _}, read_result)
             end)
    end

    test "大数据传输测试" do
      # 测试传输 1MB 的数据
      assert {:ok, "OK"} = NetworkApp.test_large_data_transfer("large_key", 1024)

      # 验证数据完整性
      {:ok, value} = NetworkApp.command(["GET", "large_key"])
      assert byte_size(value) == 1024 * 1024
    end

    test "管道命令测试" do
      assert {:ok, results} = NetworkApp.test_pipeline_in_unstable_network("normal_pipe", 100)
      assert length(results) == 100
      assert Enum.all?(results, &(&1 == "OK"))
    end

    test "阻塞命令测试" do
      # 测试阻塞命令（应该在超时后返回）
      assert {:ok, nil} = NetworkApp.test_blocking_command(1)
    end
  end

  describe "高延迟网络测试" do
    @describetag redis_url: @delayed_url

    test "基本连接测试" do
      assert {:ok, "PONG"} = NetworkApp.test_connectivity()
    end

    test "操作响应时间测试" do
      start_time = :os.system_time(:millisecond)
      assert {:ok, "PONG"} = NetworkApp.test_connectivity()
      end_time = :os.system_time(:millisecond)

      # 由于网络延迟设置为约100ms，操作应该需要至少100ms
      response_time = end_time - start_time
      assert response_time >= 90, "响应时间应至少为90ms，实际为#{response_time}ms"
    end

    test "超时行为测试" do
      # 设置比网络延迟短的超时时间（50ms）
      result = NetworkApp.test_timeout_behavior("timeout_key", "value", 50)

      # 应该返回超时错误
      assert {:error, %RedisPool.Error{code: :timeout_error}} = result
    end

    test "管道命令在高延迟下的性能" do
      start_time = :os.system_time(:millisecond)
      {:ok, results} = NetworkApp.test_pipeline_in_unstable_network("delayed_pipe", 10)
      end_time = :os.system_time(:millisecond)

      # 所有命令都应该成功执行
      assert length(results) == 10
      assert Enum.all?(results, &(&1 == "OK"))

      # 由于所有命令都在一个往返中发送，总响应时间应该比单独执行每个命令要短得多
      pipeline_time = end_time - start_time

      # 单独执行10个命令理论上需要至少10*100ms
      assert pipeline_time < 1000, "管道命令性能不如预期，耗时#{pipeline_time}ms"
    end

    test "重试机制测试" do
      # 测试带有重试的操作
      assert {:ok, "OK"} = NetworkApp.test_retry_mechanism("retry_key", "retry_value", 3)
    end
  end

  describe "不稳定网络测试" do
    @describetag redis_url: @unstable_url

    test "连接可靠性测试" do
      # 执行多次操作，有些可能会失败（由于10%的丢包率）
      {:ok, results} = NetworkApp.test_reliability("unstable", 20, 100)

      # 统计成功和失败的操作
      success_count =
        Enum.count(results, fn {_, write_result, _} ->
          match?({:ok, "OK"}, write_result)
        end)

      # 打印成功率，但不要断言具体值，因为这是随机的
      success_rate = success_count / 20 * 100
      IO.puts("不稳定网络成功率: #{success_rate}%")
    end

    test "重试机制有效性测试" do
      # 不使用重试
      no_retry_results =
        for _ <- 1..10 do
          NetworkApp.command(["SET", "no_retry_key", "value"])
        end

      no_retry_success = Enum.count(no_retry_results, &match?({:ok, "OK"}, &1))

      # 使用重试
      retry_results =
        for _ <- 1..10 do
          NetworkApp.test_retry_mechanism("retry_key", "value", 3)
        end

      retry_success = Enum.count(retry_results, &match?({:ok, "OK"}, &1))

      # 使用重试机制应该有更高的成功率
      assert retry_success >= no_retry_success, "重试机制没有提高成功率"

      IO.puts("不使用重试成功率: #{no_retry_success / 10 * 100}%")
      IO.puts("使用重试成功率: #{retry_success / 10 * 100}%")
    end

    test "批量操作错误恢复测试" do
      # 创建一系列键
      valid_keys = for i <- 1..5, do: "recovery_key_#{i}"
      invalid_key = "invalid_command_key"

      # 执行批量操作，包含一个会失败的命令
      {batch_result, cleanup_results} = NetworkApp.test_batch_error_recovery(valid_keys, invalid_key)

      # 批量操作应该失败
      assert {:error, _} = batch_result

      # 但清理操作应该至少部分成功
      successful_cleanups = Enum.count(cleanup_results, &match?({:ok, _}, &1))
      assert successful_cleanups > 0, "所有清理操作都失败了"
    end
  end

  describe "连接池在网络问题下的行为" do
    @describetag redis_url: @unstable_url
    @describetag pool_size: 10

    test "并发操作测试" do
      # 创建多个并发任务，模拟多个客户端
      tasks =
        for i <- 1..30 do
          Task.async(fn ->
            # 随机延迟，让任务在不同时间启动
            :timer.sleep(Enum.random(1..100))
            NetworkApp.command(["SET", "concurrent_key_#{i}", "value_#{i}"])
          end)
        end

      # 等待所有任务完成
      results = Task.await_many(tasks, 5000)

      # 计算成功和失败的操作
      success_count = Enum.count(results, &match?({:ok, "OK"}, &1))
      error_count = Enum.count(results, &match?({:error, _}, &1))

      IO.puts("并发操作成功: #{success_count}, 失败: #{error_count}")

      # 不断言具体的成功率，但至少应该有一些成功的操作
      assert success_count > 0, "所有并发操作都失败了"
    end

    test "连接池饱和测试" do
      # 创建超过连接池大小的并发请求
      pool_size = 10
      request_count = pool_size * 3

      # 使用代理进程来收集结果
      parent = self()

      # 启动请求
      for i <- 1..request_count do
        spawn(fn ->
          # 模拟长时间运行的操作
          result = NetworkApp.command(["SET", "pool_saturation_#{i}", "value"], pool_timeout: 1000)
          send(parent, {i, result})
        end)
      end

      # 收集结果
      results =
        for _ <- 1..request_count do
          receive do
            {i, result} -> {i, result}
          after
            5000 -> {:timeout, :timeout}
          end
        end

      # 分析结果
      success_count = Enum.count(results, fn {_, result} -> match?({:ok, "OK"}, result) end)

      timeout_count =
        Enum.count(results, fn {_, result} ->
          match?({:error, %RedisPool.Error{code: :timeout_error}}, result)
        end)

      other_errors =
        Enum.count(results, fn {_, result} ->
          match?({:error, _}, result) and not match?({:error, %RedisPool.Error{code: :timeout_error}}, result)
        end)

      IO.puts("连接池饱和测试结果 - 成功: #{success_count}, 超时: #{timeout_count}, 其他错误: #{other_errors}")

      # 应该有一些请求成功，一些请求超时（由于连接池已满）
      assert success_count > 0, "没有请求成功"
      assert timeout_count > 0, "没有请求超时（连接池可能没有饱和）"
    end

    test "连接恢复测试" do
      # 尝试多次连接，应该有一些成功，一些失败
      {:ok, results} = NetworkApp.test_reconnection_behavior("recovery_key", "value", 10, 200)

      # 至少应该有一些成功的操作
      success_count = Enum.count(results, fn {_, result} -> match?({:ok, "OK"}, result) end)
      assert success_count > 0, "所有重连操作都失败了"

      IO.puts("连接恢复测试 - 成功率: #{success_count / 10 * 100}%")
    end
  end
end
