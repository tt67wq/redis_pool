# RedisPool

A module that provides a Redis connection pool using NimblePool.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `redis_pool` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:redis_pool, "~> 0.1.0"}
  ]
end
```

## Usage
To use `RedisPool`, you can start the pool with `RedisPool.start_link/1` function. The function accepts a keyword list of options, including `url`, `pool_size`, and `name`.
  
```elixir
{:ok, _pid} = RedisPool.start_link(url: "redis://localhost:6379", pool_size: 10, name: :redis_pool)

# SET
RedisPool.command(:redis_pool, ["SET", "key", "value"])

# GET
RedisPool.command(:redis_pool, ["GET", "key"])

# pipeline
RedisPool.pipeline(:redis_pool, ["SET", "key1", "value1"], ["SET", "key2", "value2"])
```

