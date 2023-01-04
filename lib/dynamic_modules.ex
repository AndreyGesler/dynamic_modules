defmodule DynamicModules do
  ##############################################################################
  ##############################################################################
  @moduledoc """
  Documentation for `DynamicModules`.
  """

  use GenServer
  use Utils

  alias DynamicModules.Services.DynamicModulesService, as: DynamicModulesService

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
  ## Function
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, opts)
  end

  ##############################################################################
  @doc """
  ## Function
  """
  @impl true
  def init(state) do
    UniError.rescue_error!(
      (
        Logger.info("[#{inspect(__MODULE__)}][#{inspect(__ENV__.function)}] I will try to start DynamicModules")

        Logger.info("[#{inspect(SelfModule)}][#{inspect(__ENV__.function)}] I will try to enable notification monitor on node connection events")

        result = :net_kernel.monitor_nodes(true)

        if :ok != result do
          UniError.raise_error!(
            :CODE_CAN_NOT_ENABLE_MONITOR_ERROR,
            ["Can not enable notification monitor on node connection events"],
            reason: result
          )
        end
      )
    )

    Logger.info("[#{inspect(__MODULE__)}][#{inspect(__ENV__.function)}] I completed init part")
    {:ok, state}
  end

  ##############################################################################
  @doc """
  ## Function
  """
  @impl true
  def handle_info({:nodeup, node}, state) do
    UniError.rescue_error!(
      (
        Logger.info("[#{inspect(__MODULE__)}][#{inspect(__ENV__.function)}] Node #{inspect(node)} connected")

        {:ok, remote_postgresiar_node_name_prefixes} = Utils.get_app_env!(:postgresiar, :remote_node_name_prefixes)
        {:ok, nodes} = Utils.get_nodes_list_by_prefixes!(remote_postgresiar_node_name_prefixes, [node])

        if nodes == [] do
          Logger.warn("[#{inspect(__MODULE__)}][#{inspect(__ENV__.function)}] No postgresiar nodes in cluster, cannot start dynamic modules")
        else
          Logger.info("[#{inspect(__MODULE__)}][#{inspect(__ENV__.function)}] Got postgresiar nodes in cluster, i will try start dynamic modules")
          {:ok, _result} = DynamicModulesService.load_modules()
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
  ## Function
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
