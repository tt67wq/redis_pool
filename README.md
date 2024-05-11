<!-- MDOC !-->
# RedisPool

A module that provides a Redis connection pool using NimblePool.

## Installation


```elixir
def deps do
  [
    {:redis_pool_xyz, "~> 0.1"}
  ]
end
```
See [DOC](https://hexdocs.pm/redis_pool_xyz)

## Usage

1. Add a module using `RedisPool`:
   ```Elixir
   defmodule MyRedis do
     @moduledoc false

     use RedisPool, otp_app: :my_app

   end
   ```

2. Configure your Redis:
    ```Elixir
    url = "redis://localhost:6379"
    config = [name: :my_redis, url: url]
    config :my_app, MyRedis, config
    ```

3. Add your redis module to supervisor:
   ```Elixir
   children = [
      MyRedis
   ]
   ```

4. Enjoy your journey!
   ```Elixir
   MyRedis.command(:my_redis, ["GET", "foo"]) == {:ok, nil}
   MyRedis.command(:my_redis, ["SET", "foo", "bar"]) == {:ok, "OK"}
   MyRedis.command(:my_redis, ["GET", "foo"]) == {:ok, "bar"}

   MyReids.pipeline(:my_redis, [["SET", "foo1", "bar1"], ["SET", "foo2", "bar2"]])
   ```
