defmodule Commanded.Storage.Extreme.Adapter do
  require Logger
  @moduledoc """ 
  Interface with the Extreme EventStore driver to save and read to EVENTSTORE.
  Note that the Engine supervisor starts the driver naming it as 'EventStore'.
  """
  alias Commanded.Storage.Extreme.Mapper
  alias Extreme.Messages.WriteEventsCompleted

  @behaviour Commanded.Storage.Adapter
  @extreme Commanded.Extreme  # the pid name we called it on Commanded.Storage.Extreme.Connection

  @type aggregate_uuid        :: String.t
  @type start_version         :: String.t
  @type batch_size            :: integer()
  @type batch                 :: list()
  @type reason                :: atom()
  @type read_event_batch_size :: integer()




  @doc "Save a list of events to the stream."
  def append_to_stream(stream_id, expected_version,  pending_events) do
    correlation_id = UUID.uuid4
    # attention, erlangish pattern matching (^)
    message = Mapper.map_write_events(stream_id, pending_events)
    version = expected_version + 1 # postgre driver counts + 1, so let's fix adding 1 here
    {:ok, %WriteEventsCompleted{first_event_number: ^version}} =
      Extreme.execute(@extreme, message)
    :ok
  end


  @doc "Read stream, transforming messages in an event list ready for replay"
  def read_stream_forward(stream_id, start_version, read_event_batch_size) do
    message = Mapper.map_read_stream(stream_id, start_version, read_event_batch_size)
    case Extreme.execute(@extreme, message) do
      {:ok, events} -> Mapper.extract_events({:ok, events})
      {:error, reason} -> {:error, reason}
    end
  end

  @doc "Persist state of an aggregate or process manager"
  def persist_state(stream_id, version, module, state) do
    version2 = version + 1 # postgre driver counts + 1, so let's fix adding 1 here
    message  = Mapper.map_write_state(stream_id, version2, module, state)
    {:ok, %WriteEventsCompleted{first_event_number: ^version2}} =
      Extreme.execute(@extreme, message)
    :ok
  end


  @doc "Fetch state of an aggregate or process manager"
  def fetch_state(stream_id, state) do
    message = Mapper.map_read_backwards(stream_id)
    case Extreme.execute(@extreme, message) do
      {:ok, events} -> Mapper.extract_events({:ok, events})
      {:error, reason} -> {:error, reason}
    end
  end

end
