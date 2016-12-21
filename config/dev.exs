use Mix.Config


# dependency injection from config files
config :commanded, Commanded.Storage,
  adapter: Commanded.Storage.Extreme.Adapter


# postgre database [eventstore driver]
config :eventstore, EventStore.Storage,
  serializer: Commanded.Serialization.JsonSerializer,
  username: "postgres",
  password: "postgres",
  database: "commanded_dev",
  hostname: "localhost",
  pool_size: 10,
  extensions: [{Postgrex.Extensions.Calendar, []}]


# eventstore database [extreme driver]
config :extreme, :event_store,
  db_type: :node,
  host: "localhost",
  port: 1113,
  username: "admin",
  password: "changeit",
  reconnect_delay: 2_000,
  max_attempts: :infinity
