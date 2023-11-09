defmodule RedisPoolTest do
  @moduledoc false
  use ExUnit.Case
  # doctest RedisPool

  setup do
    url =
      "tmp/url"
      |> File.read!()
      |> String.trim()

    start_supervised!({RedisPool, name: :test, url: url})

    [name: :test]
  end

  test "get", %{name: name} do
    assert RedisPool.command(name, ["GET", "foo"]) == {:ok, nil}
  end

  test "set", %{name: name} do
    assert RedisPool.command(name, ["SET", "foo", "bar"]) == {:ok, "OK"}
  end
end
