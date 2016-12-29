defmodule Commanded.Storage.StorageTest do
  use Commanded.StorageCase

  import Commanded.Enumerable, only: [pluck: 2]
  alias Commanded.Aggregates.{Registry,Aggregate}

  defmodule ExampleAggregate do
    defstruct [
      items: [],
      last_index: 0,
    ]

    # command & event
    defmodule Commands, do: defmodule AppendItems, do: defstruct [count: 0]
    defmodule Events, do: defmodule ItemAppended, do: defstruct [index: nil]

    alias Commands.{AppendItems}
    alias Events.{ItemAppended}

    def append_items(%ExampleAggregate{last_index: last_index}, count), do:
      Enum.map(1..count, fn index -> %ItemAppended{index: last_index + index} end)

    # state mutatators
    def apply(%ExampleAggregate{items: items} = state, %ItemAppended{index: index}) do
      %ExampleAggregate{state |
        items: items ++ [index],
        last_index: index,
      }
    end
  end

  alias ExampleAggregate.Commands.{AppendItems}

  # handler
  defmodule AppendItemsHandler do
    @behaviour Commanded.Commands.Handler
    def handle(%ExampleAggregate{} = aggregate, %AppendItems{count: count}), do:
      ExampleAggregate.append_items(aggregate, count)
  end

  test "should append events to stream" do
    stream_id = "storage-test-01-" <> UUID.uuid4
    evts = ExampleAggregate.append_items(%ExampleAggregate{last_index: 0}, 9)
    # driver = Application.get_env(:commanded, Commanded.Storage, [])
    # IO.inspect driver
    res = Commanded.Storage.append_to_stream(stream_id, 0, evts)
    assert res == :ok
    # again
    evts2 = ExampleAggregate.append_items(%ExampleAggregate{last_index: 9}, 3)
    res2 = Commanded.Storage.append_to_stream(stream_id, 9, evts)
    assert res2 == :ok
  end

  test "read stream forward" do
    stream_id = "storage-test-02-" <> UUID.uuid4
    evts = ExampleAggregate.append_items(%ExampleAggregate{last_index: 0}, 9)
    res  = Commanded.Storage.append_to_stream(stream_id, 0, evts)
    res2 = Commanded.Storage.read_stream_forward(stream_id, 3, 2)
    expected_res = {:ok,
      [%Commanded.Storage.StorageTest.ExampleAggregate.Events.ItemAppended{index: 3},
      %Commanded.Storage.StorageTest.ExampleAggregate.Events.ItemAppended{index: 4}]}
    assert res2 == expected_res
  end


  test "persist state" do
    stream_id = "storage-test-03-" <> UUID.uuid4
    state  = %ExampleAggregate{
      items: ["I", "love", "coding"],
      last_index: 3
    }
    res    = Commanded.Storage.persist_state(stream_id, 0, ExampleAggregate, state)
    assert res == :ok
  end

  test "read state" do
    stream_id = "storage-test-04-" <> UUID.uuid4
    state  = %ExampleAggregate{
      items: ["I", "love", "coding"],
      last_index: 3
    }
    res = Commanded.Storage.persist_state(stream_id, 0, ExampleAggregate, state)
    res2 = Commanded.Storage.fetch_state(stream_id, "oi")
    IO.inspect res2
    assert 1 == 1
  end

  # test "should persist pending events in order applied" do
  #   aggregate_uuid = UUID.uuid4
  #
  #   {:ok, aggregate} = Registry.open_aggregate(ExampleAggregate, aggregate_uuid)
  #
  #   :ok = Aggregate.execute(aggregate, %AppendItems{count: 10}, AppendItemsHandler, :handle)
  #
  #   {:ok, recorded_events} = EventStore.read_stream_forward(aggregate_uuid, 0)
  #
  #   assert recorded_events |> pluck(:data) |> pluck(:index) == Enum.to_list(1..10)
  # end
  #
  # test "should reload persisted events when restarting aggregate process" do
  #   aggregate_uuid = UUID.uuid4
  #
  #   {:ok, aggregate} = Registry.open_aggregate(ExampleAggregate, aggregate_uuid)
  #
  #   :ok = Aggregate.execute(aggregate, %AppendItems{count: 10}, AppendItemsHandler, :handle)
  #
  #   Commanded.Helpers.Process.shutdown(aggregate)
  #
  #   {:ok, aggregate} = Registry.open_aggregate(ExampleAggregate, aggregate_uuid)
  #
  #   assert Aggregate.aggregate_uuid(aggregate) == aggregate_uuid
  #   assert Aggregate.aggregate_version(aggregate) == 10
  #   assert Aggregate.aggregate_state(aggregate) == %Commanded.Entities.EventPersistenceTest.ExampleAggregate{
  #     items: 1..10 |> Enum.to_list,
  #     last_index: 10,
  #   }
  # end
  #
  # test "should reload persisted events in batches when restarting aggregate process" do
  #   aggregate_uuid = UUID.uuid4
  #
  #   {:ok, aggregate} = Registry.open_aggregate(ExampleAggregate, aggregate_uuid)
  #
  #   :ok = Aggregate.execute(aggregate, %AppendItems{count: 100}, AppendItemsHandler, :handle)
  #   :ok = Aggregate.execute(aggregate, %AppendItems{count: 100}, AppendItemsHandler, :handle)
  #   :ok = Aggregate.execute(aggregate, %AppendItems{count: 1}, AppendItemsHandler, :handle)
  #
  #   Commanded.Helpers.Process.shutdown(aggregate)
  #
  #   {:ok, aggregate} = Registry.open_aggregate(ExampleAggregate, aggregate_uuid)
  #
  #   aggregate_state = Aggregate.aggregate_state(aggregate)
  #
  #   assert Aggregate.aggregate_uuid(aggregate) == aggregate_uuid
  #   assert Aggregate.aggregate_version(aggregate) == 201
  #   assert aggregate_state == %Commanded.Entities.EventPersistenceTest.ExampleAggregate{
  #     items: 1..201 |> Enum.to_list,
  #     last_index: 201,
  #   }
  # end
end
