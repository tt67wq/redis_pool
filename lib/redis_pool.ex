defmodule RedisPool do
  @moduledoc "README.md"
             |> File.read!()
             |> String.split("<!-- MDOC !-->")
             |> Enum.fetch!(1)

  @external_resource "README.md"
  defmacro __using__(opts) do
    quote do
      alias RedisPool.Core

      def init(config) do
        {:ok, config}
      end

      defoverridable init: 1

      def child_spec(opts) do
        %{
          id: __MODULE__,
          start: {__MODULE__, :start_link, [opts]}
        }
      end

      def start_link(config \\ []) do
        otp_app = unquote(opts[:otp_app])

        {:ok, cfg} =
          otp_app
          |> Application.get_env(__MODULE__, config)
          |> init()

        Core.start_link(cfg)
      end

      defdelegate stop(pid), to: Core
      defdelegate command(pid, command, opts \\ []), to: Core
      defdelegate pipeline(pid, command, opts \\ []), to: Core
    end
  end
end
