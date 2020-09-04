# ConcurrentLimiter: A concurrency limiter.
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: LGPL-3.0-only

defmodule ConcurrentLimiter do
  require Logger

  @moduledoc """
  A concurrency limiter. Limits the number of concurrent invocations possible, without using a worker pool or different processes.

  It can be useful in cases where you don't need a worker pool but still being able to limit concurrent calls without much overhead.
  As it internally uses `persistent_term` to store metadata, it is not made for a large number of different or dynamic limiters and
  cannot be used for things like a per-user rate limiter.

  ```elixir
  :ok = ConcurrentLimiter.new(RequestLimiter, 10, 10)
  ConcurrentLimiter.limit(RequestLimiter, fn() -> something_that_can_only_run_ten_times_concurrently() end)
  ```
  """

  @default_wait 150
  @default_max_retries 5

  @doc "Initializes a `ConcurrentLimiter`."
  @spec new(name, max_running, max_waiting, options) :: :ok | {:error, :existing}
        when name: atom(),
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
      atomics = :atomics.new(1, signed: true)

      :persistent_term.put(
        name,
        {__MODULE__, max_running, max_waiting, atomics, wait, max_retries}
      )

      :ok
    end
  end

  @doc "Adjust the limits at runtime."
  @spec set(name, new_max_running, new_max_waiting, options) :: :ok | :error
        when name: atom(),
             new_max_running: non_neg_integer(),
             new_max_waiting: non_neg_integer() | :infinity,
             options: [option],
             option: {:wait, non_neg_integer()}
  def set(name, new_max_running, new_max_waiting, options \\ []) do
    name = prefix_name(name)

    if defined?(name) do
      new_wait = Keyword.get(options, :wait)
      new_max_retries = Keyword.get(options, :max_retries)
      {__MODULE__, max_running, max_waiting, ref, wait, max_retries} = :persistent_term.get(name)

      new =
        {__MODULE__, new_max_running || max_running, new_max_waiting || max_waiting, ref,
         new_wait || wait, new_max_retries || max_retries}

      :persistent_term.put(name, new)
      :ok
    else
      :error
    end
  end

  @spec delete(name) :: :ok when name: atom()
  @doc "Deletes a limiter."
  def delete(name) do
    if defined?(name) do
      :persistent_term.put(name, nil)
    end

    :ok
  end

  @doc "Limits invocation of `fun`."
  @spec limit(name, function(), opts) :: {:error, :overload} | any()
        when name: atom(),
             opts: [option],
             option: {:wait, non_neg_integer()} | {:max_retries, non_neg_integer()}
  def limit(name, fun, opts \\ []) do
    do_limit(prefix_name(name), fun, opts, 0)
  end

  defp do_limit(name, fun, opts, retries) do
    {__MODULE__, max_running, max_waiting, ref, wait, max_retries} = :persistent_term.get(name)
    max = max_running + max_waiting
    counter = inc(ref, name)
    max_retries = Keyword.get(opts, :max_retries) || max_retries
    :telemetry.execute([:concurrent_limiter, :limit], %{counter: counter}, %{limiter: name})

    cond do
      counter <= max_running ->
        :telemetry.execute([:concurrent_limiter, :execution], %{counter: counter}, %{
          limiter: name
        })

        Process.flag(:trap_exit, true)

        try do
          fun.()
        after
          dec(ref, name)
          Process.flag(:trap_exit, false)

          receive do
            {:EXIT, _, reason} ->
              Process.exit(self(), reason)
          after
            0 -> :noop
          end
        end

      counter > max ->
        :telemetry.execute([:concurrent_limiter, :overload], %{counter: counter}, %{
          limiter: name,
          scope: "max"
        })

        dec(ref, name)
        {:error, :overload}

      retries + 1 > max_retries ->
        :telemetry.execute([:concurrent_limiter, :max_retries], %{counter: counter}, %{
          limiter: name,
          retries: retries + 1
        })

        dec(ref, name)
        {:error, :overload}

      counter > max_running ->
        :telemetry.execute([:concurrent_limiter, :wait], %{counter: counter}, %{
          limiter: name,
          retries: retries + 1
        })

        wait(ref, name, fun, wait, opts, retries + 1)
    end
  end

  defp wait(ref, name, fun, wait, opts, retries) do
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
