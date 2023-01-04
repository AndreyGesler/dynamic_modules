defmodule DynamicModules.Services.DynamicModulesService do
  ##############################################################################
  ##############################################################################
  @moduledoc """
  ## Module
  """
  use Utils

  @version_pattern ~s"""
  @version "{#}"

  ##############################################################################
  @doc \"\"\"
  ## Function
  \"\"\"
  def get_version() do
    {:ok, @version}
  end
  """

  @query "select t.id, t.name, t.version, t.order, t.state_id, t.after_create_proc, t.after_create_proc_opts, t.body from {#} as t where t.state_id = 'active' order by t.order asc"

  ##############################################################################
  @doc """
  ## Function
  """
  def get_modules_list!(db_repo, table_name)
      when not is_atom(db_repo) or not is_bitstring(table_name),
      do:
        UniError.raise_error!(
          :CODE_WRONG_FUNCTION_ARGUMENT_ERROR,
          ["db_repo, table_name cannot be nil; db_repo must be an atom; table_name must be a string"]
        )

  def get_modules_list!(db_repo, table_name) do
    query = Utils.format_string_(@query, [table_name])
    {:ok, records} = db_repo.exec_query!(query)

    records =
      if records == :CODE_NOTHING_FOUND do
        []
      else
        Enum.reduce(
          records,
          [],
          fn item, accum ->
            {:ok, module} = normalize_module(item)

            accum ++ [module]
          end
        )
      end

    {:ok, records}
  end

  ##############################################################################
  @doc """
  ## Function
  """
  def normalize_module(module)
      when not is_list(module),
      do:
        UniError.raise_error!(
          :CODE_WRONG_FUNCTION_ARGUMENT_ERROR,
          ["module cannot be nil; module must be a list"]
        )

  def normalize_module(
        [
          _id,
          name,
          version,
          _order,
          _state_id,
          after_create_proc,
          after_create_proc_opts,
          body
        ] = _module
      )
      when not is_bitstring(name) or not is_bitstring(version) or (not is_nil(after_create_proc) and not is_bitstring(after_create_proc)) or
             (not is_nil(after_create_proc_opts) and not is_bitstring(after_create_proc_opts)) or not is_bitstring(body),
      do: UniError.raise_error!(:CODE_WRONG_FUNCTION_ARGUMENT_ERROR, ["name, version, body cannot be nil; name, version, body must be a string; after_create_proc, after_create_proc_opts if not nil must be a string"])

  def normalize_module(
        [
          id,
          name,
          version,
          order,
          state_id,
          after_create_proc,
          after_create_proc_opts,
          body
        ] = _module
      ) do
    {:ok, name} = CodeUtils.string_to_code!(name)
    {:ok, after_create_proc} = CodeUtils.string_to_code!(after_create_proc)
    {:ok, after_create_proc_opts} = CodeUtils.string_to_code!(after_create_proc_opts)
    id =  UUID.binary_to_string!(id)

    module = %{
      id: id,
      name: name,
      version: version,
      order: order,
      after_create_proc: after_create_proc,
      after_create_proc_opts: after_create_proc_opts,
      body: body,
      state_id: state_id
    }

    {:ok, module}
  end

  def normalize_module(module),
    do:
      UniError.raise_error!(
        :CODE_WRONG_ARGUMENT_COMBINATION_ERROR,
        ["Wrong argument combination"],
        module: module
      )

  ##############################################################################
  @doc """
  ## Function
  """
  def load_module!(module)
      when not is_map(module),
      do: UniError.raise_error!(:CODE_WRONG_FUNCTION_ARGUMENT_ERROR, ["module cannot be nil; module must be a map"])

  def load_module!(
        %{
          id: _id,
          name: name,
          version: version,
          order: _order,
          after_create_proc: after_create_proc,
          after_create_proc_opts: after_create_proc_opts,
          body: body,
          state_id: _state_id
        } = _module
      )
      when not is_atom(name) or not is_bitstring(version) or (not is_nil(after_create_proc) and not is_atom(after_create_proc)) or
             (not is_nil(after_create_proc_opts) and not is_list(after_create_proc_opts)) or not is_bitstring(body),
      do:
        UniError.raise_error!(:CODE_WRONG_FUNCTION_ARGUMENT_ERROR, ["name, version, body cannot be nil; name must be an atom; version, body must be a string; after_create_proc if not nil must be an atom; after_create_proc_opts if not nil must be a list"])

  def load_module!(
        %{
          id: id,
          name: name,
          version: version,
          order: order,
          after_create_proc: after_create_proc,
          after_create_proc_opts: after_create_proc_opts,
          body: body,
          state_id: state_id
        } = module
      ) do
    already_loaded = CodeUtils.ensure_compiled?(name)

    {action, previous_version} =
      if already_loaded do
        if not function_exported?(name, :get_version, 0) do
          UniError.raise_error!(:CODE_FUNCTION_NOT_EXPORTED_ERROR, ["Function not exported"], module: name, function: {:get_version, 0})
        end

        {:ok, previous_version} = apply(name, :get_version, [])

        if previous_version != version do
          {:reloaded, previous_version}
        else
          {:not_loaded, previous_version}
        end
      else
        {:loaded, nil}
      end

    {action, result} =
      case action do
        val when val in [:loaded, :reloaded] ->
          body = @version_pattern <> body
          body = Utils.format_string_(body, [version])

          CodeUtils.create_module!(name, body, __ENV__)

          after_create_result =
            if is_nil(after_create_proc) do
              :no_after_create
            else
              if not function_exported?(name, after_create_proc, 1) do
                UniError.raise_error!(:CODE_FUNCTION_NOT_EXPORTED_ERROR, ["Function not exported"], module: name, function: {after_create_proc, 1})
              end

              apply(name, after_create_proc, [after_create_proc_opts])
            end

          {action, %{previous_version: previous_version, new_version: version, after_create_result: after_create_result}}

        :not_loaded ->
          {:not_loaded, %{previous_version: previous_version, new_version: previous_version, after_create_result: nil}}
      end

    module = Map.delete(module, :body)
    result = Map.put(result, :module, module)

    {:ok, {action, result}}
  end

  def load_module!(module),
    do:
      UniError.raise_error!(
        :CODE_WRONG_ARGUMENT_COMBINATION_ERROR,
        ["Wrong argument combination"],
        module: module
      )

  ##############################################################################
  @doc """
  ## Function
  """
  def load_modules!() do
    {:ok, db_repo} = get_app_env!(:db_repo)
    {:ok, table_name} = get_app_env!(:table_name)

    raise_if_empty!(db_repo, :atom, "Wrong db_repo value")
    raise_if_empty!(table_name, :string, "Wrong table_name value")

    {:ok, modules} = get_modules_list!(db_repo, table_name)

    result =
      Enum.reduce(
        modules,
        [],
        fn module, accum ->
          {:ok, result} = load_module!(module)

          {action, result} = result
          %{module: module} = result

          accum ++ [%{name: module.name, action: action, result: result}]
        end
      )

    {:ok, result}
  end

  ##############################################################################
  ##############################################################################
end
