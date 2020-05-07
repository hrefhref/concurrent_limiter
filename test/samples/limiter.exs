:ets.new(:limiter_bench, [:public, :named_table])
Limiter.new(:bench, 1_000_000_000_000_000_000_000_000_000_000_000_000_000_000_000, 0)

Benchee.run(%{
  "update_counter" => fn ->
    :ets.update_counter(:limiter_bench, "bench", {2, 1}, {"bench", 0})
  end,
  "limit" => fn ->
    Limiter.limit(:bench, fn -> :ok end)
  end
})
