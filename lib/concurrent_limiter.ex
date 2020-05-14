defmodule ConcurrentLimiter do
  require Logger

  @moduledoc """
  # Concurrent Limiter

  A concurrency limiter. Limits the number of concurrent invocations possible, without using a worker pool or different processes.

  It can be useful in cases where you don't need a worker pool but still being able to limit concurrent calls without much overhead.
  As it internally uses `persistent_term` to store metadata, and can fallback to ETS tables, it is however not made for a large number
  of limiters and cannot be used for things like a per-user rate limiter.
  """

  @doc """
  Initializes a `ConcurrentLimiter`.
  """

  @default_wait 150
  @default_max_retries 5

  @spec new(name, max_running, max_waiting, options) :: :ok | {:error, :existing} when name: atom(),
    max_running: non_neg_integer(),
    max_waiting: non_neg_integer() | :infinity,
    options: [option],
    option: {:wait, non_neg_integer()} | {:max_retries, non_neg_integer()}
  def new(name, max_running, max_waiting, options \\ []) do
    name = prefix_name(name)
    if defined?(name) do
      {:error, :existing}
    else
      wait = Keyword.get(options, :wait, @default_wait)
      max_retries = Keyword.get(options, :max_retries, @default_max_retries)
      atomics = :atomics.new(1, [signed: true])
      :persistent_term.put(name, {__MODULE__, max_running, max_waiting, atomics, wait, max_retries})
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
    name = prefix_name(name)
    if defined?(name) do
      new_wait = Keyword.get(options, :wait)
      new_max_retries = Keyword.get(options, :max_retries)
      {__MODULE__, max_running, max_waiting, ref, wait, max_retries} = :persistent_term.get(name)
      new = {__MODULE__, new_max_running || max_running, new_max_waiting || max_waiting, ref, new_wait || wait, new_max_retries || max_retries}
      :persistent_term.put(name, new)
      :ok
    else
      :error
    end
  end

  @spec limit(atom(), function(), opts) :: {:error, :overload} | any() when opts: [option],
    option: {:wait, non_neg_integer()} | {:max_retries, non_neg_integer()}
  @doc "Limits invocation of `fun`."
  def limit(name, fun, opts \\ []) do
    do_limit(prefix_name(name), fun, opts, 0)
  end

  defp do_limit(name, fun, opts, retries) do
    {__MODULE__, max_running, max_waiting, ref, wait, max_retries} = :persistent_term.get(name)
    max = max_running + max_waiting
    counter = inc(ref, name)
    max_retries = Keyword.get(opts, :max_retries) || max_retries

    cond do
      counter <= max_running ->
        try do
          fun.()
        after
          dec(ref, name)
        end

      counter > max ->
        dec(ref, name)
        {:error, :overload}

      retries + 1 > max_retries ->
        {:error, :overload}

      counter > max_running ->
        wait(ref, name, wait, fun, opts, max_retries, retries + 1)
    end
  end

  defp wait(ref, name, wait, fun, opts, max_retries, retries) do
    wait = Keyword.get(opts, :timeout) || wait
    Process.sleep(wait)
    dec(ref, name)
    do_limit(name, fun, opts, retries)
  end

  defp inc(ref, _) do
    :atomics.add_get(ref, 1, 1)
  end

  defp dec(ref, _) do
    :atomics.sub_get(ref, 1, 1)
  end

  defp prefix_name(suffix), do: Module.concat(__MODULE__, suffix)

  defp defined?(name) do
    {__MODULE__, _, _, _, _, _} = :persistent_term.get(name)
    true
  rescue
    _ -> false
  end

end
