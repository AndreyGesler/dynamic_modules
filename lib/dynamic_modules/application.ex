defmodule DynamicModules.Application do
  ##############################################################################
  ##############################################################################
  @moduledoc """
  ## Module
  """
  use Application
  use Utils

  alias DynamicModules, as: DynamicModulesWorker

  ##############################################################################
  @doc """
  # get_opts.
  """
  def get_opts do
    result = [
      strategy: :one_for_one,
      name: DynamicModules.Supervisor
    ]

    {:ok, result}
  end

  ##############################################################################
  @doc """
  # get_children!
  """
  defp get_children! do
    result = [
      {DynamicModulesWorker, []}
    ]

    {:ok, result}
  end

  ##############################################################################
  @doc """
  # Start application.
  """
  @impl true
  def start(_type, _args) do
    {:ok, children} = get_children!()
    {:ok, opts} = get_opts()

    Supervisor.start_link(children, opts)
  end

  ##############################################################################
  ##############################################################################
end
