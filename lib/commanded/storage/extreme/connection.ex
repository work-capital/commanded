if Code.ensure_loaded?(Extreme) do

  defmodule Commanded.Storage.Extreme.Connection do
    use Supervisor

    def start_link, do:
      Supervisor.start_link __MODULE__, :ok

    @extreme Commanded.Extreme  # this pid name will be used by the adapter

    def init(:ok) do
      event_store_settings = Application.get_env :extreme, :event_store

      children = [
        worker(Extreme, [event_store_settings, [name: @extreme]]),
      ]
      supervise children, strategy: :one_for_one
    end

  end

end
