defmodule RedisPoolTest do
  @moduledoc false
  use ExUnit.Case
  # doctest RedisPool
  alias RedisPool.Test.App

  setup do
    url = "redis://localhost:6379"
    config = [name: :redis_test, url: url]

    Application.put_env(:app, RedisPool.Test.App, config)

    start_supervised!(App)

    [name: :redis_test]
  end

  test "main", %{name: name} do
    assert App.command(name, ["GET", "foo"]) == {:ok, nil}
    assert App.command(name, ["SET", "foo", "bar"]) == {:ok, "OK"}
    assert App.command(name, ["GET", "foo"]) == {:ok, "bar"}
  end
end
