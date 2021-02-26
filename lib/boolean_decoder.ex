defmodule Membrane.RTP.VP8.BooleanDecoder do
  @max_int_32 4_294_967_295

  defmodule State do
    @type t :: %__MODULE__{
            input: binary(),
            range: 0..4_294_967_295,
            value: 0..4_294_967_295,
            bit_count: non_neg_integer()
          }
    defstruct [:input, :range, :value, :bit_count]
  end

  @spec init_bool_decoder(binary()) :: {:ok, State.t()}
  def init_bool_decoder(input) do
    IO.inspect(input)
    <<value::16, input::binary()>> = input

    {:ok, %State{input: input, value: value, range: 255, bit_count: 0}}
  end

  @spec read_bool(0..255, State.t()) :: {:ok, {0..1, State.t()}}
  def read_bool(prob, state) do
    split = (1 + div((state.range - 1) * prob, 256)) |> rem(@max_int_32 + 1)
    split2 = split * 256

    {ret_val, state} =
      if state.value >= split2,
        do: {1, %State{state | range: state.range - split, value: state.value - split2}},
        else: {0, %State{state | range: split}}

    state =
      Enum.reduce_while(1..@max_int_32, state, fn _i, state ->
        if state.range < 128 do
          value = (state.value * 2) |> rem(@max_int_32)
          range = (state.range * 2) |> rem(@max_int_32)
          bit_count = state.bit_count + 1

          {bit_count, value, input} =
            if(bit_count == 8) do
              <<next_byte, input::binary()>> = state.input
              {0, value + next_byte, input}
            else
              {bit_count, value, state.input}
            end

          {:cont, %State{state | value: value, range: range, bit_count: bit_count, input: input}}
        else
          {:halt, state}
        end
      end)

    IO.inspect(ret_val)
    {:ok, {ret_val, state}}
  end

  @spec read_literal(integer, State.t()) :: {:ok, {integer, State.t()}}
  def read_literal(num_bits, state) do
    {v, state} =
      1..num_bits
      |> Enum.reduce({0, state}, fn _i, {v, state} ->
        v = 2 * v
        {:ok, {bool, state}} = read_bool(128, state)
        {v + bool, state}
      end)

    {:ok, {v, state}}
  end
end
