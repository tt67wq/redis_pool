defmodule RedisPool.Integration.StandaloneTest do
  @moduledoc """
  Redis 单实例集成测试。
  测试 RedisPool 与单个 Redis 实例的交互。

  运行测试前需要启动测试环境：
  ```
  cd test/docker && ./setup_test_env.sh start
  ```
  """

  use ExUnit.Case, async: false

  alias RedisPool.Test.Integration.StandaloneApp

  @redis6_url "redis://:redis_password@localhost:6379"
  @redis7_url "redis://:redis_password@localhost:6380"

  setup_all do
    # 确保测试环境已经启动
    # 在实际环境中，这里可能需要检查 Redis 是否可用

    # 返回测试中需要的数据
    %{
      redis6_url: @redis6_url,
      redis7_url: @redis7_url
    }
  end

  setup context do
    # 为每个测试配置应用
    redis_url = context[:redis_url] || @redis6_url
    config = [url: redis_url, pool_size: 5]
    Application.put_env(:redis_pool_xyz, RedisPool.Test.Integration.StandaloneApp, config)

    # 启动应用
    start_supervised!(StandaloneApp)

    # 清理测试数据
    StandaloneApp.clean_test_data()

    :ok
  end

  describe "Redis 6.2 测试" do
    @describetag redis_url: @redis6_url

    test "基本连接测试" do
      assert {:ok, "PONG"} = StandaloneApp.health_check()
    end

    test "SET 和 GET 命令" do
      assert {:ok, "OK"} = StandaloneApp.command(["SET", "test_key", "test_value"])
      assert {:ok, "test_value"} = StandaloneApp.command(["GET", "test_key"])
    end

    test "带过期时间的键" do
      assert {:ok, "OK"} = StandaloneApp.set_key_with_expiry("expire_key", "expire_value", 1)
      assert {:ok, "expire_value"} = StandaloneApp.command(["GET", "expire_key"])

      # 等待键过期
      :timer.sleep(1500)
      assert {:ok, nil} = StandaloneApp.command(["GET", "expire_key"])
    end

    test "事务操作" do
      commands = [
        ["SET", "tx_key1", "value1"],
        ["SET", "tx_key2", "value2"],
        ["GET", "tx_key1"]
      ]

      assert {:ok, result} = StandaloneApp.transaction(commands)
      # 最后一个元素是 EXEC 的结果，包含所有命令的结果
      assert List.last(result) == ["OK", "OK", "value1"]
    end

    test "批量操作" do
      key_values = [
        {"batch_key1", "value1"},
        {"batch_key2", "value2"},
        {"batch_key3", "value3"}
      ]

      assert {:ok, results} = StandaloneApp.batch_set(key_values)
      assert length(results) == 3
      assert Enum.all?(results, &(&1 == "OK"))

      keys = Enum.map(key_values, fn {k, _} -> k end)
      assert {:ok, values} = StandaloneApp.batch_get(keys)

      assert values == %{
               "batch_key1" => "value1",
               "batch_key2" => "value2",
               "batch_key3" => "value3"
             }
    end

    test "列表操作" do
      assert {:ok, 3} = StandaloneApp.command(["LPUSH", "list_key", "item1", "item2", "item3"])
      assert {:ok, ["item3", "item2", "item1"]} = StandaloneApp.command(["LRANGE", "list_key", "0", "-1"])
    end

    test "哈希操作" do
      assert {:ok, 2} = StandaloneApp.command(["HSET", "hash_key", "field1", "value1", "field2", "value2"])
      assert {:ok, "value1"} = StandaloneApp.command(["HGET", "hash_key", "field1"])
      assert {:ok, ["field1", "value1", "field2", "value2"]} = StandaloneApp.command(["HGETALL", "hash_key"])
    end

    test "集合操作" do
      assert {:ok, 3} = StandaloneApp.command(["SADD", "set_key", "member1", "member2", "member3"])
      assert {:ok, 1} = StandaloneApp.command(["SISMEMBER", "set_key", "member1"])
      assert {:ok, 0} = StandaloneApp.command(["SISMEMBER", "set_key", "nonexistent"])
    end

    test "有序集合操作" do
      assert {:ok, 3} = StandaloneApp.command(["ZADD", "zset_key", "1", "member1", "2", "member2", "3", "member3"])
      assert {:ok, ["member1", "member2", "member3"]} = StandaloneApp.command(["ZRANGE", "zset_key", "0", "-1"])
    end

    test "管道命令的错误处理" do
      commands = [
        ["SET", "pipe_key1", "value1"],
        # 无效命令
        ["INVALID_COMMAND"],
        ["SET", "pipe_key2", "value2"]
      ]

      # 管道会执行所有命令，但是第二个命令会失败
      assert {:ok, _} = StandaloneApp.pipeline(commands)

      # 第一个和第三个命令应该已经成功执行
      assert {:ok, "value1"} = StandaloneApp.command(["GET", "pipe_key1"])
      assert {:ok, "value2"} = StandaloneApp.command(["GET", "pipe_key2"])
    end
  end

  describe "Redis 7.0 测试" do
    @describetag redis_url: @redis7_url

    test "基本连接测试" do
      assert {:ok, "PONG"} = StandaloneApp.health_check()
    end

    test "SET 和 GET 命令" do
      assert {:ok, "OK"} = StandaloneApp.command(["SET", "test_key", "test_value"])
      assert {:ok, "test_value"} = StandaloneApp.command(["GET", "test_key"])
    end

    test "Redis 7.0 新功能 - 函数" do
      # 注意：Redis 7.0 添加了 FUNCTION 命令，但测试环境可能没有启用
      # 这里只是演示，可能需要根据实际环境调整
      result = StandaloneApp.command(["FUNCTION", "LIST"])
      assert match?({:ok, _}, result)
    end
  end

  describe "连接池功能测试" do
    test "连接池并发操作" do
      # 模拟多个并发操作
      tasks =
        for i <- 1..20 do
          Task.async(fn ->
            key = "concurrent_key_#{i}"
            value = "value_#{i}"

            assert {:ok, "OK"} = StandaloneApp.command(["SET", key, value])
            assert {:ok, ^value} = StandaloneApp.command(["GET", key])

            # 返回结果以便验证
            {key, value}
          end)
        end

      # 等待所有任务完成并验证结果
      results = Task.await_many(tasks)
      assert length(results) == 20
    end

    test "连接池满负荷测试" do
      # 创建超过池大小的并发请求
      pool_size = 5
      request_count = pool_size * 2

      tasks =
        for i <- 1..request_count do
          Task.async(fn ->
            # 执行耗时操作
            key = "overload_key_#{i}"
            # 创建较大的值
            value = String.duplicate("x", 1000)

            assert {:ok, "OK"} = StandaloneApp.command(["SET", key, value])
            # 模拟操作耗时
            :timer.sleep(100)
            assert {:ok, ^value} = StandaloneApp.command(["GET", key])

            i
          end)
        end

      # 所有请求应该最终都成功完成
      results = Task.await_many(tasks, 5000)
      assert length(results) == request_count
    end
  end

  describe "错误处理测试" do
    test "无效命令" do
      result = StandaloneApp.command(["INVALID_COMMAND"])
      assert {:error, %RedisPool.Error{code: :command_error}} = result
    end

    test "语法错误" do
      result = StandaloneApp.command(["SET"])
      assert {:error, %RedisPool.Error{code: :command_error}} = result
    end
  end
end
