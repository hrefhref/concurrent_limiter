infinite = 1_000_000_000_000_000_000_000_000_000_000_000_000_000_000_000
Limiter.new(:bench, infinite, 0)
Limiter.new(:bench_s, infinite, 0, ets: LimiterTest)

concurrent = [{:read_concurrency, true}, {:write_concurrency, true}]

Limiter.new(:bench_rw, infinite, 0)
Limiter.new(:bench_s_rw, infinite, 0, ets: LimiterTest, ets_opts: concurrent)

single = %{
  "Limiter.limit/2" => fn ->
    Limiter.limit(:bench, fn -> :ok end)
  end,
  "Limiter.limit/2 with concurrency" => fn ->
    Limiter.limit(:bench_rw, fn -> :ok end)
  end,
  "Limiter:limit/2 with shared ets" => fn ->
    Limiter.limit(:bench_s, fn -> :ok end)
  end,
  "Limiter:limit/2 with shared ets and concurrency" => fn ->
    Limiter.limit(:bench_s_rw, fn -> :ok end)
  end
}

IO.puts("\n\n\n\nsingle, sequential\n\n\n\n")
Benchee.run(single, parallel: 1)
IO.puts("\n\n\n\nsingle, parallel\n\n\n\n")
Benchee.run(single, parallel: System.schedulers_online())
