# DynamicModules

**TODO: Add description**

## Installation

```elixir
def deps do
  [
    {:dynamic_modules, "~> 0.1.0"},
    # OR
    {:dynamic_modules, in_umbrella: true}
  ]
end
```

## Config

### Runtime config

```elixir
import Config

import ConfigUtils, only: [get_env!: 3, get_env!: 2, get_env_name!: 1, in_container!: 0]

{:ok, in_container} = in_container!()

if in_container do
  config :logger,
    handle_otp_reports: true,
    backends: [
      :console
    ]

  config :logger,
         :console,
         level: get_env!(get_env_name!("CONSOLE_LOG_LEVEL"), :atom, :info),
         format: get_env!(get_env_name!("LOG_FORMAT"), :string, "[$date] [$time] [$level] [$node] [$metadata] [$levelpad] [$message]\n"),
         metadata: :all
else
  config :logger,
    handle_otp_reports: true,
    backends: [
      :console,
      {LoggerFileBackend, :info_log},
      {LoggerFileBackend, :error_log}
    ]

  config :logger,
         :console,
         level: get_env!(get_env_name!("CONSOLE_LOG_LEVEL"), :atom, :info),
         format: get_env!(get_env_name!("LOG_FORMAT"), :string, "[$date] [$time] [$level] [$node] [$metadata] [$levelpad] [$message]\n"),
         metadata: :all

  config :logger,
         :info_log,
         level: :info,
         path: get_env!(get_env_name!("LOG_PATH"), :string, "log") <> "/#{Node.self()}/info.log",
         format: get_env!(get_env_name!("LOG_FORMAT"), :string, "[$date] [$time] [$level] [$node] [$metadata] [$levelpad] [$message]\n"),
         metadata: :all

  config :logger,
         :error_log,
         level: :error,
         path: get_env!(get_env_name!("LOG_PATH"), :string, "log") <> "/#{Node.self()}/error.log",
         format: get_env!(get_env_name!("LOG_FORMAT"), :string, "[$date] [$time] [$level] [$node] [$metadata] [$levelpad] [$message]\n"),
         metadata: :all
end

config :dynamic_modules,
  db_repo: Repo,
  table_name: "akaket.modules"

if config_env() in [:dev] do
end

if config_env() in [:prod] do
end

```

### Database table

```sql
CREATE TABLE "module"
(
    id                     uuid        DEFAULT uuid_generate_v1() NOT NULL,           -- Id
    "name"                 varchar(128)                           NOT NULL,           -- Version
    "version"              varchar(64)                            NOT NULL,           -- Version
    after_create_proc      varchar(64) NULL,                                          -- After module create proc as elixir atom
    after_create_proc_opts text NULL,                                                 -- After module create proc opts as elixir code
    body                   text                                   NOT NULL,           -- Body as elixir code
    "order"                int8                                   NOT NULL,           -- Order
    state_id               varchar(64) DEFAULT 'active':: character varying NOT NULL, -- State id: active, inactive
    -- Any other fields
    CONSTRAINT module_pk PRIMARY KEY (id)
);

select t.id,
       t.name,
       t.version,
       t.order,
       t.state_id,
       t.after_create_proc,
       t.after_create_proc_opts,
       t.body
from {#} as t
where t.state_id = 'active'
order by t.order asc

```