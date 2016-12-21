defmodule Commanded.Storage.Extreme.Mapper do
  @moduledoc """
  Map raw events to event data structs ready to be persisted to the event store.
  """

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



  @doc "create a write message for a list of events"
  def map_write_events(stream, events) do
    proto_events = Enum.map(events, &create_event/1) # map the list of structs to event messages
    Extreme.Messages.WriteEvents.new(
      event_stream_id: stream,
      expected_version: -2,
      events: proto_events,
      require_master: false
    )
  end

  @doc "create one event message based on a struct"
  defp create_event(event) do
    Extreme.Messages.NewEvent.new(
      event_id: Extreme.Tools.gen_uuid(),
      event_type: to_string(event.__struct__),
      data_content_type: 0,
      metadata_content_type: 0,
      data: Commanded.Storage.Serialization.encode(event),
      meta: ""
    )
  end

end
