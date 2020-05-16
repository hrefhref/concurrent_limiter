# ConcurrentLimiter: A concurrency limiter.
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: LGPL-3.0-only

defmodule ConcurrentLimiterTest do
  use ExUnit.Case
  doctest ConcurrentLimiter

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
