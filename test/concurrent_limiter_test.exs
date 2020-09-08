# ConcurrentLimiter: A concurrency limiter.
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: LGPL-3.0-only

defmodule ConcurrentLimiterTest do
  use ExUnit.Case
  doctest ConcurrentLimiter

  test "limited to one" do
    name = "l1"
    ConcurrentLimiter.new(name, 1, 0, max_retries: 0)
    endless = fn -> :timer.sleep(10_000) end
    spawn(fn -> ConcurrentLimiter.limit(name, endless) end)
    :timer.sleep(5)
    {:error, :overload} = ConcurrentLimiter.limit(name, endless)
    {:error, :overload} = ConcurrentLimiter.limit(name, endless)
    {:error, :overload} = ConcurrentLimiter.limit(name, endless)
  end

  test "decrements correctly when current pid exits" do
    name = "l1crash"
    ConcurrentLimiter.new(name, 1, 0, max_retries: 0)
    endless = fn -> :timer.sleep(100) end

    pid =
      spawn(fn ->
        ConcurrentLimiter.limit(name, endless)
      end)

    # let some time for spawn to execute
    :timer.sleep(5)
    {:error, :overload} = ConcurrentLimiter.limit(name, endless)
    Process.exit(pid, :kill)
    # let some time for exit to execute
    :timer.sleep(5)
    :ok = ConcurrentLimiter.limit(name, fn -> :ok end)
  end

  test "limiter is atomic" do
    name = "test"
    ConcurrentLimiter.new(name, 2, 2)
    self = self()

    spawn_link(fn -> sleepy(self, name, 500) end)
    spawn_link(fn -> sleepy(self, name, 500) end)
    spawn_link(fn -> sleepy(self, name, 500) end)
    spawn_link(fn -> sleepy(self, name, 500) end)
    spawn_link(fn -> sleepy(self, name, 500) end)
    assert_receive :ok, 2000
    assert_receive :ok, 2000
    assert_receive {:error, :overload}, 2000
    assert_receive :ok, 2000
    assert_receive :ok, 2000
  end

  defp sleepy(parent, name, duration) do
    result =
      ConcurrentLimiter.limit(name, fn ->
        send(parent, :ok)
        Process.sleep(duration)
        :ok
      end)

    case result do
      :ok -> :ok
      other -> send(parent, other)
    end
  end
end
