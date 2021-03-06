defmodule Commanded.ProcessManagers.ProcessManagerInstance do
  @moduledoc """
  Defines an instance of a process manager.
  """
  use GenServer
  require Logger

  alias Commanded.ProcessManagers.Persistence
  alias Commanded.ProcessManagers.{ProcessRouter,ProcessManagerInstance}

  defstruct [
    command_dispatcher: nil,
    process_manager_name: nil,
    process_manager_module: nil,
    process_uuid: nil,
    process_state: nil,
    last_seen_event_id: 0,
  ]

  def start_link(command_dispatcher, process_manager_name, process_manager_module, process_uuid) do
    GenServer.start_link(__MODULE__, %ProcessManagerInstance{
      command_dispatcher: command_dispatcher,
      process_manager_name: process_manager_name,
      process_manager_module: process_manager_module,
      process_uuid: process_uuid,
      process_state: struct(process_manager_module),
    })
  end

  def init(%ProcessManagerInstance{} = state) do
    GenServer.cast(self, {:fetch_state})
    {:ok, state}
  end

  @doc "Handle the given event by delegating to the process manager module"
  def process_event(process_manager, %EventStore.RecordedEvent{} = event, process_router), do:
    GenServer.cast(process_manager, {:process_event, event, process_router})

  @doc "Fetch the process state of this instance"
  def process_state(process_manager), do:
    GenServer.call(process_manager, {:process_state})

  def handle_call({:process_state}, _from, %ProcessManagerInstance{process_state: process_state} = state), do:
    {:reply, process_state, state}

  @doc "Attempt to fetch intial process state from snapshot storage"
  def handle_cast({:fetch_state}, %ProcessManagerInstance{} = state) do
    state = Persistence.fetch_state(state)
    {:noreply, state}
  end

  @doc "Handle the given event, using the process manager module, against the current process state"
  def handle_cast({:process_event, %EventStore.RecordedEvent{event_id: event_id} = event, process_router}, 
    %ProcessManagerInstance{last_seen_event_id: last_seen_event_id} = state)
    when not is_nil(last_seen_event_id) and event_id <= last_seen_event_id
  do
    # already seen event, so just ack
    ack_event(event, process_router)

    {:noreply, state}
  end

  def handle_cast({:process_event, %EventStore.RecordedEvent{event_id: event_id} = event, process_router}, 
    %ProcessManagerInstance{command_dispatcher: command_dispatcher, process_manager_module: process_manager_module, 
    process_state: process_state} = state) do
      case handle_event(process_manager_module, process_state, event) do
        {:error, reason} ->
          Logger.warn(fn -> "process manager instance failed to handle event id #{inspect event_id} due to: #{inspect reason}" end)
          {:noreply, state}

        commands ->
          :ok = dispatch_commands(List.wrap(commands), command_dispatcher)

          process_state = mutate_state(process_manager_module, process_state, event)

          state = %ProcessManagerInstance{state |
            process_state: process_state,
            last_seen_event_id: event_id,
          }

          Persistence.persist_state(state, event_id)
          ack_event(event, process_router)

          {:noreply, state}
      end
  end

  # process instance is given the event and returns applicable commands (may be none, one or many)
  defp handle_event(process_manager_module, process_state, %EventStore.RecordedEvent{data: data}), do:
    process_manager_module.handle(process_state, data)

  # update the process instance's state by applying the event
  defp mutate_state(process_manager_module, process_state, %EventStore.RecordedEvent{data: data}), do:
    process_manager_module.apply(process_state, data)

  defp dispatch_commands([], _command_dispatcher), do: :ok
  defp dispatch_commands(commands, command_dispatcher) when is_list(commands) do
    Enum.each(commands, fn command ->
      Logger.debug(fn -> "process manager instance attempting to dispatch command: #{inspect command}" end)
      :ok = command_dispatcher.dispatch(command)
    end)
  end

  defp ack_event(%EventStore.RecordedEvent{event_id: event_id}, process_router), do:
    :ok = ProcessRouter.ack_event(process_router, event_id)

  defp process_state_uuid(%ProcessManagerInstance{process_manager_name: process_manager_name, process_uuid: process_uuid}), 
    do: "#{process_manager_name}-#{process_uuid}"

end
