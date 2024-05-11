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

      @name Module.concat(__MODULE__, Core)

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

        cfg
        |> Keyword.put(:name, @name)
        |> Core.start_link()
      end

      defp delegate(method, args), do: apply(Core, method, [@name | args])

      def stop, do: delegate(:stop, [])
      def command(command, opts \\ []), do: delegate(:command, [command, opts])
      def pipeline(command, opts \\ []), do: delegate(:pipeline, [command, opts])
    end
  end
end
