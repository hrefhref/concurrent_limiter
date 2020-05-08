infinite = 1_000_000_000_000_000_000_000_000_000_000_000_000_000_000_000

Limiter.new(:bench_u_0, infinite, 0, backend: {:ets, LimiterTest0, []})
Limiter.new(:bench_u_1, infinite, 0, backend: {:ets, LimiterTest1, []})
Limiter.new(:bench_u_2, infinite, 0, backend: {:ets, LimiterTest2, []})
Limiter.new(:bench_u_3, infinite, 0, backend: {:ets, LimiterTest3, []})

Limiter.new(:bench_a_0, infinite, 0, backend: :atomics)
Limiter.new(:bench_a_1, infinite, 0, backend: :atomics)
Limiter.new(:bench_a_2, infinite, 0, backend: :atomics)
Limiter.new(:bench_a_3, infinite, 0, backend: :atomics)

Limiter.new(:bench_s_0, infinite, 0, backend: {:ets, LimiterTest, []})
Limiter.new(:bench_s_1, infinite, 0, backend: {:ets, LimiterTest, []})
Limiter.new(:bench_s_2, infinite, 0, backend: {:ets, LimiterTest, []})
Limiter.new(:bench_s_3, infinite, 0, backend: {:ets, LimiterTest, []})

rw = [{:read_concurrency, true}, {:write_concurrency, true}]

Limiter.new(:bench_u_rw0, infinite, 0, backend: {:ets, LimiterTestRW0, rw})
Limiter.new(:bench_u_rw1, infinite, 0, backend: {:ets, LimiterTestRW1, rw})
Limiter.new(:bench_u_rw2, infinite, 0, backend: {:ets, LimiterTestRW2, rw})
Limiter.new(:bench_u_rw3, infinite, 0, backend: {:ets, LimiterTestRW3, rw})

Limiter.new(:bench_s_rw0, infinite, 0, backend: {:ets, LimiterTestRW, rw})
Limiter.new(:bench_s_rw1, infinite, 0, backend: {:ets, LimiterTestRW, rw})
Limiter.new(:bench_s_rw2, infinite, 0, backend: {:ets, LimiterTestRW, rw})
Limiter.new(:bench_s_rw3, infinite, 0, backend: {:ets, LimiterTestRW, rw})

multiple = %{
  "Limiter.limit/2 unique ets" => fn ->
    limiter = Enum.random([:bench_u_0, :bench_u_1, :bench_u_2, :bench_u_3])
    Limiter.limit(limiter, fn -> :ok end)
  end,
  "Limiter:limit/2 shared ets" => fn ->
    limiter = Enum.random([:bench_s_0, :bench_s_1, :bench_s_2, :bench_s_3])
    Limiter.limit(limiter, fn -> :ok end)
  end,
  "Limiter.limit/2 unique ets, concurrency" => fn ->
    limiter = Enum.random([:bench_u_rw0, :bench_u_rw1, :bench_u_rw2, :bench_u_rw3])
    Limiter.limit(limiter, fn -> :ok end)
  end,
  "Limiter:limit/2 shared ets, concurrency" => fn ->
    limiter = Enum.random([:bench_s_rw0, :bench_s_rw1, :bench_s_rw2, :bench_s_rw3])
    Limiter.limit(limiter, fn -> :ok end)
  end,
  "Limiter:limit/2 atomics" => fn ->
    limiter = Enum.random([:bench_a_0, :bench_a_1, :bench_a_2, :bench_a_3])
    Limiter.limit(limiter, fn -> :ok end)
  end
}

IO.puts("\n\n\n\nmulti, sequential\n\n\n\n")
Benchee.run(multiple)
IO.puts("\n\n\n\nmulti, parallel\n\n\n\n")
Benchee.run(multiple, parallel: System.schedulers_online())
