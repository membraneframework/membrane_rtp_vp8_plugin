defmodule Membrane.RTP.VP8.BooleanDecoderTest do
  use ExUnit.Case

  alias Membrane.RTP.VP8.BooleanDecoder

  test "decoding prob 64/256" do
    input = <<65, 54, 37, 13, 21>>

    {:ok, boolean_decoder} = BooleanDecoder.init_bool_decoder(input)

    {actual_output_list, state} =
      1..3
      |> Enum.map_reduce(boolean_decoder, fn x, bd ->
        {:ok, {v, state}} = BooleanDecoder.read_literal(8, bd)

        {v, state}
      end)

    actual_output = actual_output_list |> to_string()

    expected_output = <<65, 54, 37>>

    assert expected_output == actual_output
  end
end
