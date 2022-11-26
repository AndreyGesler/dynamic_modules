import Config

import ConfigUtils, only: [get_env!: 3, get_env!: 2, get_env_name!: 1]

if config_env() in [:prod, :dev] do
  config :dynamic_modules,
    cookie: get_env!(get_env_name!("CLUSTER_COOKIE"), :atom),
    postgresiar_remote_node_name_prefixes: get_env!(get_env_name!("POSTGRESIAR_REMOTE_NODE_NAME_PREFIXES"), :list_of_regex)

  config :logger,
         :console,
         level: get_env!(get_env_name!("CONSOLE_LOG_LEVEL"), :atom, :info)

  config :logger,
         :info_log,
         path: get_env!(get_env_name!("LOG_PATH"), :string, "log") <> "/#{Node.self()}/info.log"

  config :logger,
         :error_log,
         path: get_env!(get_env_name!("LOG_PATH"), :string, "log") <> "/#{Node.self()}/error.log"
end
