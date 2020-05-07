defmodule Limiter do
  @ets __MODULE__.ETS

  def new(name, max_running, max_waiting) do
    name = atom_name(name)
    :persistent_term.put(name, {max_running, max_waiting})
    :ets.new(name, [:public, :named_table])
    :ok
  end

  def limit(name, fun) do
    {max_running, max_waiting} = :persistent_term.get(atom_name(name))
    max = max_running + max_waiting
    counter = inc(name)

    cond do
      counter <= max_running ->
        fun.()

      counter > max ->
        {:error, :overload}

      counter > max_running ->
        wait(name, fun)
    end
  after
    dec(name)
  end

  defp wait(name, fun) do
    Process.sleep(150)
    dec(name)
    limit(name, fun)
  end

  defp inc(name) do
    name = atom_name(name)
    :ets.update_counter(name, name, {2, 1}, {name, 0})
  end

  def dec(name) do
    name = atom_name(name)
    :ets.update_counter(name, name, {2, -1}, {name, 0})
  end

  defp atom_name(suffix), do: Module.concat(@ets, suffix)
end
