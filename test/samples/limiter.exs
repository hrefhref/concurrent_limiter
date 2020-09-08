infinite = 1_000_000_000_000_000_000_000_000_000_000_000_000_000_000_000
ConcurrentLimiter.new(:bench, infinite, 0)
ConcurrentLimiter.new(:bench_no_sentinel, infinite, 0, sentinel: false)

single = %{
  "ConcurrentLimiter.limit/2 (with sentinels)" => fn ->
    ConcurrentLimiter.limit(:bench, fn -> :ok end)
  end,
  "ConcurrentLimiter.limit/2 (without sentinels)" => fn ->
    ConcurrentLimiter.limit(:bench_no_sentinel, fn -> :ok end)
  end
}

IO.puts("\n\n\n\nsingle, sequential\n\n\n\n")
Benchee.run(single, parallel: 1)
IO.puts("\n\n\n\nsingle, parallel\n\n\n\n")
Benchee.run(single, parallel: System.schedulers_online())
