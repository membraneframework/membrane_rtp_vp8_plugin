defmodule Membrane.RTP.VP8.PayloaderTest do
  use ExUnit.Case

  alias Membrane.Buffer
  alias Membrane.RTP.VP8.PayloadDescriptor
  alias Membrane.RTP.VP8.Payloader

  test "fragmentation not required" do
    input_payload = <<1, 2, 3>>
    input_buffer = %Buffer{payload: input_payload}

    payload_descriptor =
      %PayloadDescriptor{x: 0, n: 0, s: 1, partition_index: 0} |> PayloadDescriptor.serialize()

    expected_output_payload = payload_descriptor <> input_payload

    {[], payloader_state} = Payloader.handle_init(nil, %Payloader{max_payload_size: 3})

    assert {[
              buffer:
                {:output,
                 [
                   %Buffer{
                     metadata: %{rtp: %{marker: true}},
                     payload: expected_output_payload
                   }
                 ]}
            ],
            payloader_state} ==
             Payloader.handle_process(:input, input_buffer, nil, payloader_state)
  end

  test "three complete chunks" do
    input_payload = <<1, 2, 3, 4, 5, 6, 7, 8, 9>>
    input_buffer = %Buffer{payload: input_payload}

    first_descriptor =
      %PayloadDescriptor{x: 0, n: 0, s: 1, partition_index: 0} |> PayloadDescriptor.serialize()

    following_descriptor =
      %PayloadDescriptor{x: 0, n: 0, s: 0, partition_index: 0} |> PayloadDescriptor.serialize()

    {[], payloader_state} = Payloader.handle_init(nil, %Payloader{max_payload_size: 3})

    assert {[
              buffer:
                {:output,
                 [
                   %Buffer{
                     metadata: %{rtp: %{marker: false}},
                     payload: first_descriptor <> <<1, 2, 3>>
                   },
                   %Buffer{
                     metadata: %{rtp: %{marker: false}},
                     payload: following_descriptor <> <<4, 5, 6>>
                   },
                   %Buffer{
                     metadata: %{rtp: %{marker: true}},
                     payload: following_descriptor <> <<7, 8, 9>>
                   }
                 ]}
            ],
            payloader_state} ==
             Payloader.handle_process(:input, input_buffer, nil, payloader_state)
  end

  test "two complete chunks one incomplete" do
    input_payload = <<1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11>>
    input_buffer = %Buffer{payload: input_payload}

    first_descriptor =
      %PayloadDescriptor{x: 0, n: 0, s: 1, partition_index: 0} |> PayloadDescriptor.serialize()

    following_descriptor =
      %PayloadDescriptor{x: 0, n: 0, s: 0, partition_index: 0} |> PayloadDescriptor.serialize()

    {[], payloader_state} = Payloader.handle_init(nil, %Payloader{max_payload_size: 3})

    assert {[
              buffer:
                {:output,
                 [
                   %Buffer{
                     metadata: %{rtp: %{marker: false}},
                     payload: first_descriptor <> <<1, 2, 3>>
                   },
                   %Buffer{
                     metadata: %{rtp: %{marker: false}},
                     payload: following_descriptor <> <<4, 5, 6>>
                   },
                   %Buffer{
                     metadata: %{rtp: %{marker: false}},
                     payload: following_descriptor <> <<7, 8, 9>>
                   },
                   %Buffer{
                     metadata: %{rtp: %{marker: true}},
                     payload: following_descriptor <> <<10, 11>>
                   }
                 ]}
            ],
            payloader_state} ==
             Payloader.handle_process(:input, input_buffer, nil, payloader_state)
  end
end
