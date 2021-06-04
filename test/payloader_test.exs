defmodule Membrane.RTP.VP8.PayloaderTest do
  use ExUnit.Case

  alias Membrane.RTP.VP8.Payloader
  alias Membrane.RTP.VP8.Payloader.State
  alias Membrane.RTP.VP8.PayloadDescriptor
  alias Membrane.Buffer

  test "fragmentation not required" do
    input_payload = <<1, 2, 3>>
    input_buffer = %Buffer{payload: input_payload}

    payload_descriptor =
      %PayloadDescriptor{x: 0, n: 0, s: 1, partition_index: 0} |> PayloadDescriptor.serialize()

    expected_output_payload = payload_descriptor <> input_payload

    {:ok, payloader_state} = Payloader.handle_init(%Payloader{max_payload_size: 3})

    assert {{:ok,
             [
               buffer:
                 {:output,
                  [
                    %Buffer{
                      metadata: %{rtp: %{marker: true}},
                      payload: expected_output_payload
                    }
                  ]},
               redemand: :output
             ]},
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

    {:ok, payloader_state} = Payloader.handle_init(%Payloader{max_payload_size: 3})

    assert {{:ok,
             [
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
                  ]},
               redemand: :output
             ]},
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

    {:ok, payloader_state} = Payloader.handle_init(%Payloader{max_payload_size: 3})

    assert {{:ok,
             [
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
                  ]},
               redemand: :output
             ]},
            payloader_state} ==
             Payloader.handle_process(:input, input_buffer, nil, payloader_state)
      # Testing.Pipeline.stop_and_terminate(pipeline, blocking?: true)
  end
end
