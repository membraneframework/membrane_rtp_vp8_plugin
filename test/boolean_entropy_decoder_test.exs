defmodule Membrane.RTP.VP8.BooleanEntropyDecoderTest do
  use ExUnit.Case

  alias Membrane.RTP.VP8.BooleanEntropyDecoder

  test "decoding with prob 128/256" do
    input = <<65, 54, 37, 13, 21>>

    {:ok, boolean_decoder} = BooleanEntropyDecoder.init(input)

    {actual_output_list, state} =
      1..3
      |> Enum.map_reduce(boolean_decoder, fn x, bd ->
        {v, state} = BooleanEntropyDecoder.read_literal(bd, 8)

        {v, state}
      end)

    actual_output = to_string(actual_output_list)

    expected_output = <<65, 54, 37>>

    assert expected_output == actual_output
  end
end
