import Config

config :nimiq_rpc,
  url: System.get_env("NIMIQ_RPC_URL", "https://rpc-testnet.nimiqcloud.com"),
  username: System.get_env("NIMIQ_RPC_USERNAME", ""),
  password: System.get_env("NIMIQ_RPC_PASSWORD", "")
