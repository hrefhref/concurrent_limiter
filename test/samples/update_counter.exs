:ets.new(:limiter_bench, [:public, :named_table])
:ets.new(:limiter_bench_concurrent, [:public, :named_table, {:read_concurrency, false}, {:write_concurrency, true}])
atomics = :atomics.new(1, [])

update_counter = 
  %{
    "ets:update_counter" => fn ->
      :ets.update_counter(:limiter_bench, "bench", {2, 1}, {"bench", 0})
    end,
    "ets:update_counter concurrent" => fn ->
      :ets.update_counter(:limiter_bench, "bench", {2, 1}, {"bench", 0})
    end,
    "atomics:add_get" => fn ->
      :atomics.add_get(atomics, 1, 1)
    end,
  }

Benchee.run(update_counter, parallel: 1)
Benchee.run(update_counter, parallel: System.schedulers_online())

