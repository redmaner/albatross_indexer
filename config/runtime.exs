import Config

config :nimiq_rpc,
  url: System.get_env("NIMIQ_RPC_URL", "https://rpc-testnet.nimiqcloud.com"),
  username: System.get_env("NIMIQ_RPC_USERNAME", ""),
  password: System.get_env("NIMIQ_RPC_PASSWORD", "")

config :indexer,
  max_syncer_jobs: System.schedulers_online() * 2

config :mongo_db,
  opts: [
    name: :mongo,
    url: System.get_env("MONGODB_URL", "mongodb://localhost:27017/albatross"),
    username: System.get_env("MONGODB_USERNAME", "albatross"),
    password: System.get_env("MONGODB_PASSWORD", "safepasswordorsomething"),
    pool_size: System.get_env("MONGODB_POOLSIZE", "32") |> String.to_integer(),
    auth_source: System.get_env("MONGODB_AUTH_SOURCE", "admin")
  ]
