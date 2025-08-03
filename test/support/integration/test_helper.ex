defmodule RedisPool.Test.Integration.TestHelper do
  @moduledoc """
  集成测试助手模块，提供测试环境管理和辅助函数。
  """

  require Logger

  @doc """
  检查测试环境是否已启动并就绪

  返回:
    - :ok - 测试环境已就绪
    - {:error, reason} - 测试环境未就绪，包含原因
  """
  def check_environment do
    # 检查 Redis 单实例
    case check_redis_connection("localhost", 6379, "redis_password") do
      :ok ->
        # 检查延迟 Redis
        case check_redis_connection("localhost", 6384, "redis_password") do
          :ok -> :ok
          error -> error
        end

      error ->
        error
    end
  end

  @doc """
  检查 Redis 连接是否可用
  """
  def check_redis_connection(host, port, password) do
    redis_url = "redis://:#{password}@#{host}:#{port}"

    case Redix.start_link(redis_url) do
      {:ok, conn} ->
        try do
          case Redix.command(conn, ["PING"]) do
            {:ok, "PONG"} ->
              Redix.stop(conn)
              :ok

            other ->
              Redix.stop(conn)
              {:error, "Redis连接检查失败: #{inspect(other)}"}
          end
        rescue
          e ->
            Redix.stop(conn)
            {:error, "Redis连接异常: #{inspect(e)}"}
        end

      error ->
        {:error, "无法连接到Redis (#{host}:#{port}): #{inspect(error)}"}
    end
  end

  @doc """
  启动 Docker 测试环境
  """
  def start_test_environment do
    Logger.info("正在启动 Redis 测试环境...")

    case System.cmd("sh", ["-c", "cd #{docker_dir()} && ./setup_test_env.sh start"]) do
      {output, 0} ->
        Logger.info("Redis 测试环境启动成功")
        {:ok, output}

      {output, code} ->
        Logger.error("Redis 测试环境启动失败，退出码: #{code}")
        {:error, "启动测试环境失败: #{output}"}
    end
  end

  @doc """
  停止 Docker 测试环境
  """
  def stop_test_environment do
    Logger.info("正在停止 Redis 测试环境...")

    case System.cmd("sh", ["-c", "cd #{docker_dir()} && ./setup_test_env.sh stop"]) do
      {_output, 0} ->
        Logger.info("Redis 测试环境已停止")
        :ok

      {output, code} ->
        Logger.error("Redis 测试环境停止失败，退出码: #{code}")
        {:error, "停止测试环境失败: #{output}"}
    end
  end

  @doc """
  清理 Docker 测试环境
  """
  def clean_test_environment do
    Logger.info("正在清理 Redis 测试环境...")

    case System.cmd("sh", ["-c", "cd #{docker_dir()} && ./setup_test_env.sh clean"]) do
      {_output, 0} ->
        Logger.info("Redis 测试环境已清理")
        :ok

      {output, code} ->
        Logger.error("Redis 测试环境清理失败，退出码: #{code}")
        {:error, "清理测试环境失败: #{output}"}
    end
  end

  @doc """
  获取测试环境状态
  """
  def get_environment_status do
    case System.cmd("sh", ["-c", "cd #{docker_dir()} && ./setup_test_env.sh status"]) do
      {output, 0} ->
        {:ok, output}

      {output, code} ->
        {:error, "获取测试环境状态失败 (#{code}): #{output}"}
    end
  end

  @doc """
  模拟网络问题

  类型:
    - :delay - 增加延迟
    - :loss - 增加丢包率
    - :reset - 重置网络设置
  """
  def simulate_network_issue(type, target \\ "redis_pool_redis6", params \\ nil) do
    case type do
      :delay ->
        delay_ms = params || "100ms 20ms"

        cmd =
          "docker exec #{target} sh -c \"apk add --no-cache iproute2 && tc qdisc add dev eth0 root netem delay #{delay_ms}\""

        System.cmd("sh", ["-c", cmd])

      :loss ->
        loss_percent = params || "10%"

        cmd =
          "docker exec #{target} sh -c \"apk add --no-cache iproute2 && tc qdisc add dev eth0 root netem loss #{loss_percent}\""

        System.cmd("sh", ["-c", cmd])

      :reset ->
        cmd = "docker exec #{target} sh -c \"tc qdisc del dev eth0 root\""
        System.cmd("sh", ["-c", cmd])

      _ ->
        {:error, "不支持的网络问题类型: #{type}"}
    end
  end

  @doc """
  模拟 Redis 故障

  类型:
    - :stop - 停止容器
    - :start - 启动容器
    - :restart - 重启容器
  """
  def simulate_redis_failure(type, target \\ "redis_pool_redis6") do
    case type do
      :stop ->
        System.cmd("docker", ["stop", target])

      :start ->
        System.cmd("docker", ["start", target])

      :restart ->
        System.cmd("docker", ["restart", target])

      _ ->
        {:error, "不支持的故障类型: #{type}"}
    end
  end

  @doc """
  执行 Redis 命令
  """
  def redis_command(host, port, password, command) do
    redis_url = "redis://:#{password}@#{host}:#{port}"

    case Redix.start_link(redis_url) do
      {:ok, conn} ->
        try do
          result = Redix.command(conn, command)
          Redix.stop(conn)
          result
        rescue
          e ->
            Redix.stop(conn)
            {:error, "执行命令异常: #{inspect(e)}"}
        end

      error ->
        {:error, "无法连接到Redis: #{inspect(error)}"}
    end
  end

  # 辅助函数，获取Docker目录路径
  defp docker_dir do
    Path.join(File.cwd!(), "test/docker")
  end
end
