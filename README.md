# RedisPool

A module that provides a Redis connection pool using NimblePool.

## Installation


```elixir
def deps do
  [
    {:redis_pool_xyz, "~> 0.1.0"}
  ]
end
```
See [DOC](https://hexdocs.pm/redis_pool_xyz/0.1.0)

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

