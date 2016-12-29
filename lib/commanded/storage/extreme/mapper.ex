defmodule Commanded.Storage.Extreme.Mapper do
  @moduledoc """
  Map raw events to event data structs ready to be persisted to the event store.
  """
  alias Extreme.Messages.ReadStreamEvents
  alias Extreme.Messages.WriteEvents
  alias Extreme.Messages.NewEvent

  def map_to_event_data(events, correlation_id) when is_list(events) do
    Enum.map(events, &map_to_event_data(&1, correlation_id))
  end

  def map_to_event_data(event, correlation_id) do
    %EventStore.EventData{
      correlation_id: correlation_id,
      event_type: Atom.to_string(event.__struct__),
      data: event,
      metadata: %{}
    }
  end

  def map_from_recorded_events(recorded_events) when is_list(recorded_events) do
    Enum.map(recorded_events, &map_from_recorded_event/1)
  end

  def map_from_recorded_event(%EventStore.RecordedEvent{data: data}) do
    data
  end

  def extract_events({:ok, response}),   do: {:ok, Enum.map(response.events, &extract_data/1)}
  def extract_events({:error,_}),        do: {:error, :not_found}
  def extract_events({:error,_,_}),      do: {:error, :not_found}

  # rebuild the struct from a string stored in the eventstore
  def extract_data(message) do
    st = message.event.event_type |> make_alias |> struct
    message.event.data |> deserialize(st)
  end

  # transforms a ":Jim" string into a Jim atom alias
  def make_alias(name) do
    name_s = String.to_atom(name)
    ast = {:__aliases__, [alias: false], [name_s]}
    {result, _} = Code.eval_quoted(ast)
    result
  end

  defp deserialize(data, struct \\ nil),
    do: Commanded.Storage.Serialization.decode(data, struct)

  @doc "create a read stream message"
  def map_read_stream(stream_id, from_event_number, max_count) do
    %ReadStreamEvents{
      event_stream_id: stream_id,
      from_event_number: from_event_number,
      max_count: max_count,
      resolve_link_tos: true,
      require_master: false
    }
  end

  def map_read_backwards(stream_id) do
    Extreme.Messages.ReadStreamEventsBackward.new(
      event_stream_id: stream_id,
      from_event_number: -1,
      max_count: 1,
      resolve_link_tos: true,
      require_master: false
    )
  end

  @doc "create a write message for a list of events"
  def map_write_state(stream, version, module, state) do
    proto_events = Enum.map(state, &create_event/1) # map the list of structs to event messages
    WriteEvents.new(
      event_stream_id: stream,
      expected_version: version,
      events: state,
      require_master: false
    )
  end

  @doc "create a write message for a list of events"
  def map_write_events(stream, events) do
    proto_events = Enum.map(events, &create_event/1) # map the list of structs to event messages
    WriteEvents.new(
      event_stream_id: stream,
      expected_version: -2,
      events: proto_events,
      require_master: false
    )
  end

  @doc "create one event message based on a struct"
  defp create_event(event) do
    NewEvent.new(
      event_id: Extreme.Tools.gen_uuid(),
      event_type: to_string(event.__struct__),
      data_content_type: 0,
      metadata_content_type: 0,
      data: Commanded.Storage.Serialization.encode(event),
      meta: ""
    )
  end

end
