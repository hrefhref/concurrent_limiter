infinite = 1_000_000_000_000_000_000_000_000_000_000_000_000_000_000_000
parallel = case Integer.parse(System.get_env("PARALLEL", "")) do
  {int, _} -> int
  _ -> System.schedulers_online()/2
end

multi_count = case Integer.parse(System.get_env("MULTI", "")) do
  {int, _} -> int
  _ -> parallel
end

names = fn(prefix) ->
  for i <- 1..multi_count do
    Module.concat(MultiConcurrentLimiterBenchmark, "#{prefix}#{i}")
  end
end


bench_unique = for name <- names.("u") do
  ConcurrentLimiter.new(name, infinite, 0, backend: {:ets, name, []})
  name
end

IO.inspect(bench_unique)

bench_atomics = for name <- names.("a") do
  ConcurrentLimiter.new(name, infinite, 0, backend: :atomics)
  name
end

bench_shared = for name <- names.("s") do
  ConcurrentLimiter.new(name, infinite, 0, backend: {:ets, ConcurrentLimiterTest, []})
  name
end

rw = [{:read_concurrency, true}, {:write_concurrency, true}]

bench_unique_rw = for name <- names.("u_rw") do
  ConcurrentLimiter.new(name, infinite, 0, backend: {:ets, name, rw})
  name
end

bench_shared_rw = for name <- names.("s_rw") do
  ConcurrentLimiter.new(name, infinite, 0, backend: {:ets, ConcurrentLimiterTestRW, rw})
  name
end

multiple = %{
  "ConcurrentLimiter.limit/2 unique ets" => fn ->
    limiter = Enum.random(bench_unique)
    ConcurrentLimiter.limit(limiter, fn -> :ok end)
  end,
  "ConcurrentLimiter:limit/2 shared ets" => fn ->
    limiter = Enum.random(bench_shared)
    ConcurrentLimiter.limit(limiter, fn -> :ok end)
  end,
  "ConcurrentLimiter.limit/2 unique ets, concurrency" => fn ->
    limiter = Enum.random(bench_unique_rw)
    ConcurrentLimiter.limit(limiter, fn -> :ok end)
  end,
  "ConcurrentLimiter:limit/2 shared ets, concurrency" => fn ->
    limiter = Enum.random(bench_shared_rw)
    ConcurrentLimiter.limit(limiter, fn -> :ok end)
  end,
  "ConcurrentLimiter:limit/2 atomics" => fn ->
    limiter = Enum.random(bench_atomics)
    ConcurrentLimiter.limit(limiter, fn -> :ok end)
  end
}

IO.puts("\n\n\n\nmulti, sequential\n\n\n\n")
Benchee.run(multiple)
IO.puts("\n\n\n\nmulti, parallel\n\n\n\n")
Benchee.run(multiple, parallel: System.schedulers_online())
