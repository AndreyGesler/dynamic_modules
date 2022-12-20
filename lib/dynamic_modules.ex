defmodule DynamicModules do
  ##############################################################################
  ##############################################################################
  @moduledoc """
  Documentation for `DynamicModules`.
  """

  use GenServer
  use Utils

  ##############################################################################
  @doc """
  Supervisor's child specification
  """
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]}
    }
  end

  ##############################################################################
  @doc """

  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, opts)
  end

  ##############################################################################
  @doc """

  """
  @impl true
  def init(state) do
    UniError.rescue_error!(
      (
        Utils.ensure_all_started!([:inets, :ssl])

        Logger.info("[#{inspect(__MODULE__)}][#{inspect(__ENV__.function)}] I will try set cookie")
        {:ok, cookie} = get_app_env!(:cookie)
        raise_if_empty!(cookie, :atom, "Wrong cookie value")
        Node.set_cookie(Node.self(), cookie)

        Logger.info("[#{inspect(__MODULE__)}][#{inspect(__ENV__.function)}] I will try to enable notification monitor on node connection events")

        result = :net_kernel.monitor_nodes(true)

        if :ok != result do
          UniError.raise_error!(:CODE_CAN_NOT_ENABLE_MONITOR_ERROR, ["Can not enable notification monitor on node connection events"], reason: result)
        end

        # {:ok, throw_if_connect_to_node_fail} = Utils.get_app_env!(:throw_if_connect_to_node_fail)
        # raise_if_empty!(throw_if_connect_to_node_fail, :boolean)

        # Logger.info("[#{inspect(__MODULE__)}][#{inspect(__ENV__.function)}] I will try to connect ot email sender nodes")
        # {:ok, email_sender_nodes} = Utils.get_app_env!(:email_sender_nodes)
        # raise_if_empty!(email_sender_nodes, :list)

        # {:ok, email_sender_nodes} = Utils.list_of_strings_to_list_of!(email_sender_nodes)
        # Utils.connect_to_nodes!(email_sender_nodes, throw_if_connect_to_node_fail)
      )
    )

    Logger.info("[#{inspect(__MODULE__)}][#{inspect(__ENV__.function)}] I completed init part")
    {:ok, state}
  end

  ##############################################################################
  @doc """

  """
  @impl true
  def handle_info({:nodeup, node}, state) do
    UniError.rescue_error!(
      (
        Logger.info("[#{inspect(__MODULE__)}][#{inspect(__ENV__.function)}] Node #{inspect(node)} connected")

        {:ok, remote_postgresiar_node_name_prefixes} = get_app_env!(:postgresiar_remote_node_name_prefixes)
        {:ok, nodes} = Utils.get_nodes_list_by_prefixes!(remote_postgresiar_node_name_prefixes, [node])

        if nodes == [] do
          Logger.warn("[#{inspect(__MODULE__)}][#{inspect(__ENV__.function)}] No postgresiar nodes in cluster, cannot start dynamic modules")
        else
          Logger.info("[#{inspect(__MODULE__)}][#{inspect(__ENV__.function)}] Got postgresiar nodes in cluster, i will try start dynamic modules")
          # {:ok, pid} = KafkaDynamicModulesService.start_dynamic_moduless!()
        end
      )
    )

    {:noreply, state}
  end

  @impl true
  def handle_info({:nodedown, node}, state) do
    Logger.info("[#{inspect(__MODULE__)}][#{inspect(__ENV__.function)}] Node #{inspect(node)} disconnected")

    {:noreply, state}
  end

  ##############################################################################
  @doc """

  """
  def load_module(module)
      when not is_map(module),
      do: UniError.raise_error!(:CODE_WRONG_FUNCTION_ARGUMENT_ERROR, ["module cannot be nil; module must be a map"])

  def load_module(
        %{
          id: id,
          version: version,
          after_create_proc: after_create_proc,
          after_create_proc_opts: after_create_proc_opts,
          body: body,
          order: _order,
          state_id: "active"
        } = _module
      )
      when not is_atom(id) or not is_bitstring(version) or (not is_nil(after_create_proc) and not is_atom(after_create_proc)) or
             (not is_nil(after_create_proc_opts) and not is_list(after_create_proc_opts)) or not is_bitstring(body),
      do: UniError.raise_error!(:CODE_WRONG_FUNCTION_ARGUMENT_ERROR, ["id, version, body cannot be nil; id must be an atom; version, body must be a string; after_create_proc if not nil must be an atom; after_create_proc_opts if not nil must be a list"])

  def load_module(
        %{
          id: id,
          version: version,
          after_create_proc: after_create_proc,
          after_create_proc_opts: after_create_proc_opts,
          body: body,
          order: _order,
          state_id: "active"
        } = _module
      ) do
    already_loaded = :code.is_loaded(id)

    {action, current_version} =
      if already_loaded do
        {:ok, current_version} = apply(id, :version, [])

        if current_version != version do
          {:recreated, current_version}
        else
          {:not_created, current_version}
        end
      else
        {:created, nil}
      end

    result =
      case action do
        val when val in [:created, :recreated] ->
          Utils.create_module!(id, body, __ENV__)

          after_create_result =
            if is_nil(after_create_proc) do
              :no_after_create
            else
              after_create_proc_opts =
                if is_nil(after_create_proc_opts) do
                  []
                else
                  [after_create_proc_opts]
                end

              apply(id, after_create_proc, after_create_proc_opts)
            end

          {action, %{id: id, previous_version: current_version, current_version: version, after_create_result: after_create_result}}

        :not_created ->
          {:not_created, %{id: id, previous_version: nil, current_version: current_version, after_create_result: nil}}
      end

    {:ok, result}
  end

  def load_module(module),
    do:
      UniError.raise_error!(
        :CODE_WRONG_ARGUMENT_COMBINATION_ERROR,
        ["Wrong argument combination"],
        module: module
      )

  ##############################################################################
  @doc """
  ping.

  ## Examples

      iex> DynamicModules.ping()
      :pong

  """
  def ping do
    :pong
  end

  ##############################################################################
  @doc """

  """
  def info!() do
    {:ok, dynamic_modules_config} = Utils.get_app_all_env!(:dynamic_modules)

    {:ok,
     %{
       dynamic_modules_config: dynamic_modules_config
     }}
  end

  ##############################################################################
  ##############################################################################
end
