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
    {:ok, %WriteEventsCompleted{last_event_number: ^expected_version}} =
      Extreme.execute(@extreme, message)
  end


  @doc "Read stream, transforming messages in an event list ready for replay"
  def read_stream_forward(stream_id, start_version, read_event_batch_size) do

    # case EventStore.read_stream_forward(stream_id, start_version, read_event_batch_size) do
    #   {:ok, batch} ->
    #     {:ok, Mapper.map_from_recorded_events(batch)}
    #   {:error, reason} ->
    #     {:error, reason}
    # end
  end

  @doc "Persist state of an aggregate or process manager"
  def persist_state(stream_id, version, module, state) do

    # :ok = EventStore.record_snapshot(%EventStore.Snapshots.SnapshotData{
    #     source_uuid: stream_id,
    #     source_version: version,
    #     source_type: Atom.to_string(module),
    #     data: state
    #   })
  end


  @doc "Fetch state of an aggregate or process manager"
  def fetch_state(stream_id, state) do

    # case EventStore.read_snapshot(stream_id) do
    #     {:ok, snapshot} ->
    #       {:ok, snapshot.data, snapshot.source_version}
    #     {:error, :snapshot_not_found} ->
    #       {:error, :snapshot_not_found}
    # end
  end

end
