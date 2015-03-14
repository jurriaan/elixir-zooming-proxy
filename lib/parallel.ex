defmodule Parallel do
  def map_reduce(collection, accumulator, function, reduce_function) do
    Enum.reduce(spawn_parallel(collection, function), accumulator, fn (_pid, acc) ->
      receive do { _pid, result } -> reduce_function.(result, acc) end
    end)
  end

  def map(collection, function) do
    Enum.map(spawn_parallel(collection, function), fn (pid) ->
      receive do { ^pid, result } -> result end
    end)
  end

  defp spawn_parallel(collection, function) do
    me = self
    collection |>
    Enum.map(fn (elem) ->
      spawn_link fn -> (send me, { self, function.(elem) }) end
    end)
  end
end
