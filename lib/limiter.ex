defmodule Limiter do
  require Logger

  @moduledoc """
  # Limiter

  A concurrency limiter. Limits the number of concurrent invocations possible, without using a worker pool or different processes.

  It supports two storage methods:

  * **[atomics](https://erlang.org/doc/man/atomics.html)** recommended and default if your OTP is > 21.2.
  * **[ets](https://erlang.org/doc/man/ets.html)** either with a single table per Limiter (faster) or a shared table.

  You would however always want to use atomics, ets is mostly there for backwards compatibility.
  """

  @doc """
  Initializes a `Limiter`.
  """

  @spec new(name, max_running, max_waiting, options) :: :ok | {:error, :existing} when name: atom(),
    max_running: non_neg_integer(),
    max_waiting: non_neg_integer() | :infinity,
    options: [option],
    option: {:wait, non_neg_integer()} | backend,
    backend: :atomics | ets_backend,
    ets_backend: :ets | {:ets, atom()} | {:ets, ets_name :: atom(), ets_options :: []}
  def new(name, max_running, max_waiting, options \\ []) do
    name = atom_name(name)
    if defined?(name) do
      {:error, :existing}
    else
      wait = Keyword.get(options, :wait, 150)
      backend = Keyword.get(options, :backend, default_backend())
      {:ok, backend} = setup_backend(backend)
      :persistent_term.put(name, {__MODULE__, max_running, max_waiting, backend, wait})
      :ok
    end
  end

  @spec set(name, new_max_running, new_max_waiting, options) :: :ok | :error when name: atom(),
    new_max_running: non_neg_integer(),
    new_max_waiting: non_neg_integer() | :infinity,
    options: [option],
    option: {:wait, non_neg_integer()}
  @doc "Adjust the limiter limits at runtime"
  def set(name, new_max_running, new_max_waiting, options \\ []) do
    name = atom_name(name)
    if defined?(name) do
      new_wait = Keyword.get(options, :wait)
      {__MODULE__, max_running, max_waiting, backend, wait} = :persistent_term.get(name)
      new = {__MODULE__, new_max_running || max_running, new_max_waiting || max_waiting, backend, new_wait || wait}
      :persistent_term.put(name, new)
      :ok
    else
      :error
    end
  end

  @spec limit(atom(), function()) :: {:error, :overload} | any()
  @doc "Limits invocation of `fun`."
  def limit(name, fun) do
    do_limit(atom_name(name), fun)
  end

  defp do_limit(name, fun) do
    {__MODULE__, max_running, max_waiting, backend, wait} = :persistent_term.get(name)
    max = max_running + max_waiting
    counter = inc(backend, name)

    cond do
      counter <= max_running ->
        try do
          fun.()
        after
          dec(backend, name)
        end

      counter > max ->
        dec(backend, name)
        {:error, :overload}

      counter > max_running ->
        wait(backend, name, wait, fun)
    end
  end

  defp wait(backend, name, wait, fun) do
    Process.sleep(wait)
    dec(backend, name)
    do_limit(name, fun)
  end

  defp inc({:ets, ets}, name) do
    :ets.update_counter(ets, name, {2, 1}, {name, 0})
  end

  defp inc({:atomics, ref}, _) do
    :atomics.add_get(ref, 1, 1)
  end

  defp dec({:ets, ets}, name) do
    :ets.update_counter(ets, name, {2, -1}, {name, 0})
  end

  defp dec({:atomics, ref}, _) do
    :atomics.sub_get(ref, 1, 1)
  end

  defp atom_name(suffix), do: Module.concat(__MODULE__, suffix)

  defp defined?(name) do
    {__MODULE__, _, _, _, _, _} = :persistent_term.get(name)
    true
  rescue
    _ -> false
  end

  defp default_backend() do
    if Code.ensure_loaded?(:atomics) do
      :atomics
    else
      Logger.debug("Limiter: atomics not available, using ETS backend")
      :ets
    end
  end

  defp setup_backend(:ets) do
    setup_backend({:ets, ETS})
  end

  defp setup_backend({:ets, name}) do
    setup_backend({:ets, name, [{:write_concurrency, true}, {:read_concurrency, true}]})
  end

  defp setup_backend({:ets, name, options}) do
    ets_name = atom_name(name)

    case :ets.whereis(ets_name) do
      :undefined -> :ets.new(ets_name, [:public, :named_table] ++ options)
      _ -> nil
    end
    {:ok, {:ets, ets_name}}
  end

  defp setup_backend(:atomics) do
    {:ok, {:atomics, :atomics.new(1, [signed: true])}}
  end

end
