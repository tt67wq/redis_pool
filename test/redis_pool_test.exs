defmodule RedisPoolTest do
  @moduledoc false
  use ExUnit.Case
  # doctest RedisPool
  alias RedisPool.Test.App

  setup do
    url = "redis://localhost:6379"
    config = [url: url]

    Application.put_env(:app, RedisPool.Test.App, config)

    start_supervised!(App)

    %{}
  end

  test "main" do
    App.command(["DEL", "foo"])
    assert App.command(["PING"]) == {:ok, "PONG"}
    assert App.command(["GET", "foo"]) == {:ok, nil}
    assert App.command(["SET", "foo", "bar"]) == {:ok, "OK"}
    assert App.command(["GET", "foo"]) == {:ok, "bar"}
  end
end
