:ets.new(:limiter_bench, [:public, :named_table])

Benchee.run(
  %{
    "ets:update_counter" => fn ->
      :ets.update_counter(:limiter_bench, "bench", {2, 1}, {"bench", 0})
    end
  },
  parallel: 1
)

Benchee.run(
  %{
    "ets:update_counter" => fn ->
      :ets.update_counter(:limiter_bench, "bench", {2, 1}, {"bench", 0})
    end
  },
  parallel: System.schedulers_online()
)
