infinite = 1_000_000_000_000_000_000_000_000_000_000_000_000_000_000_000
ConcurrentLimiter.new(:bench, infinite, 0)
ConcurrentLimiter.new(:bench_s, infinite, 0, ets: ConcurrentLimiterTest)

concurrent = [{:read_concurrency, true}, {:write_concurrency, true}]

ConcurrentLimiter.new(:bench_rw, infinite, 0)
ConcurrentLimiter.new(:bench_s_rw, infinite, 0, ets: ConcurrentLimiterTest, ets_opts: concurrent)

single = %{
  "ConcurrentLimiter.limit/2" => fn ->
    ConcurrentLimiter.limit(:bench, fn -> :ok end)
  end,
  "ConcurrentLimiter.limit/2 with concurrency" => fn ->
    ConcurrentLimiter.limit(:bench_rw, fn -> :ok end)
  end,
  "ConcurrentLimiter:limit/2 with shared ets" => fn ->
    ConcurrentLimiter.limit(:bench_s, fn -> :ok end)
  end,
  "ConcurrentLimiter:limit/2 with shared ets and concurrency" => fn ->
    ConcurrentLimiter.limit(:bench_s_rw, fn -> :ok end)
  end
}

IO.puts("\n\n\n\nsingle, sequential\n\n\n\n")
Benchee.run(single, parallel: 1)
IO.puts("\n\n\n\nsingle, parallel\n\n\n\n")
Benchee.run(single, parallel: System.schedulers_online())
