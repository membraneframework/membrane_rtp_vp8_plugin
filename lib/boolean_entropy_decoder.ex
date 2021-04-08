defmodule Membrane.RTP.VP8.BooleanEntropyDecoder do
  @moduledoc """
  This file contains implementation of boolean decoder based on RFC6386:
  https://tools.ietf.org/html/rfc6386#section-7.3

  The decoder is used during the payloading phase. Recommended method of payloading
  requires knowledge about the amount of coefficient partitions. This detail is contained in
  the frame header which is unfortunately in the compressed part of frame. Without
  decoder reading data from compressed part is impossible.

  Short note about coding in VP8 (based on RFC6386)
  In VP8 arithmetic coding is used - it means that entire data stream is considered as the
  binary expansion of a single number with 0 <= x < 1. The coding of each bool restricts the
  possible values of x in proportion to the probability of what is coded.

  State of boolean decoder consists of input left to decode, range, value and bit count.
  """

  @max_int_32 4_294_967_295

  @opaque t :: %__MODULE__{
            input: binary(),
            range: 0..4_294_967_295,
            value: 0..4_294_967_295,
            bit_count: non_neg_integer()
          }
  defstruct [:input, :range, :value, :bit_count]

  @spec init_bool_decoder(binary()) :: {:ok, t()}
  def init_bool_decoder(input) do
    <<value::16, input::binary()>> = input

    {:ok, %__MODULE__{input: input, value: value, range: 255, bit_count: 0}}
  end

  @spec read_bool(t(), 0..255) :: {0..1, t()}
  def read_bool(state, prob) do
    split = (1 + div((state.range - 1) * prob, 256)) |> rem(@max_int_32 + 1)

    # note that in order to compare most significant byte of 16bit value with split we need to shift split by on byte left
    split_shifted = split * 256

    {ret_val, state} =
      if state.value >= split_shifted,
        do:
          {1, %__MODULE__{state | range: state.range - split, value: state.value - split_shifted}},
        else: {0, %__MODULE__{state | range: split}}

    state =
      Enum.reduce_while(1..7, state, fn _i, state ->
        if state.range < 128 do
          value = (state.value * 2) |> rem(@max_int_32)
          range = (state.range * 2) |> rem(@max_int_32)
          bit_count = state.bit_count + 1

          {bit_count, value, input} =
            if bit_count == 8 do
              <<next_byte, input::binary()>> = state.input
              {0, value + next_byte, input}
            else
              {bit_count, value, state.input}
            end

          {:cont,
           %__MODULE__{state | value: value, range: range, bit_count: bit_count, input: input}}
        else
          {:halt, state}
        end
      end)

    {ret_val, state}
  end

  @spec read_literal(t(), integer) :: {integer, t()}
  def read_literal(state, num_bits) do
    {v, state} =
      1..num_bits
      |> Enum.reduce({0, state}, fn _i, {v, state} ->
        {bool, state} = state |> read_bool(128)
        {2 * v + bool, state}
      end)

    {v, state}
  end
end
