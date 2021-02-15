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
  end

  test "advanced payloading test" do
    input0 = <<2::3, 0::5>>
    input1 = <<1>>
    input2 = <<0>>

    # above gieves us 01000000 00000001 00000000, which gives headers size 1010 -> 10, and frame type -> interframe
    # so the header size is 13 and lets assume we've got 4 partitions, so last two bits are set to 10
    header = input0 <> input1 <> input2 <> <<0, 0, 0, 0, 0, 0, 0, 0, 0, 2>>

    # the header is followed by partition sizes, lets assume each partition is size of 5, note: sizes are in little endian
    size1 = <<5::24-little>>
    size2 = <<5::24-little>>
    size3 = <<5::24-little>>
    # so the sizes have to be followed by 25 bytes of partitions
    partitions = for(_i <- 1..20, do: 5) |> :binary.list_to_bin()

    frame = header <> size1 <> size2 <> size3 <> partitions

    input_buffer = %Buffer{payload: frame}

    {:ok, payloader_state} =
      Payloader.handle_init(%Payloader{max_payload_size: 5, fragmentation_method: :advanced})

    assert {{:ok,
             [
               buffer:
                 {:output,
                  [
                    %Buffer{
                      metadata: %{rtp: %{marker: false}},
                      payload:
                        PayloadDescriptor.serialize(%PayloadDescriptor{
                          x: 0,
                          n: 0,
                          s: 1,
                          partition_index: 0
                        }) <> input0 <> input1 <> input2 <> <<0, 0>>
                    },
                    %Buffer{
                      metadata: %{rtp: %{marker: false}},
                      payload:
                        PayloadDescriptor.serialize(%PayloadDescriptor{
                          x: 0,
                          n: 0,
                          s: 0,
                          partition_index: 0
                        }) <> <<0, 0, 0, 0, 0>>
                    },
                    %Buffer{
                      metadata: %{rtp: %{marker: false}},
                      payload:
                        PayloadDescriptor.serialize(%PayloadDescriptor{
                          x: 0,
                          n: 0,
                          s: 0,
                          partition_index: 0
                        }) <> <<0, 0, 2, 5, 0>>
                    },
                    %Buffer{
                      metadata: %{rtp: %{marker: false}},
                      payload:
                        PayloadDescriptor.serialize(%PayloadDescriptor{
                          x: 0,
                          n: 0,
                          s: 0,
                          partition_index: 0
                        }) <> <<0, 5, 0, 0, 5>>
                    },
                    %Buffer{
                      metadata: %{rtp: %{marker: false}},
                      payload:
                        PayloadDescriptor.serialize(%PayloadDescriptor{
                          x: 0,
                          n: 0,
                          s: 0,
                          partition_index: 0
                        }) <> <<0, 0>>
                    },
                    %Buffer{
                      metadata: %{rtp: %{marker: false}},
                      payload:
                        PayloadDescriptor.serialize(%PayloadDescriptor{
                          x: 0,
                          n: 0,
                          s: 0,
                          partition_index: 1
                        }) <> <<5, 5, 5, 5, 5>>
                    },
                    %Buffer{
                      metadata: %{rtp: %{marker: false}},
                      payload:
                        PayloadDescriptor.serialize(%PayloadDescriptor{
                          x: 0,
                          n: 0,
                          s: 0,
                          partition_index: 2
                        }) <> <<5, 5, 5, 5, 5>>
                    },
                    %Buffer{
                      metadata: %{rtp: %{marker: false}},
                      payload:
                        PayloadDescriptor.serialize(%PayloadDescriptor{
                          x: 0,
                          n: 0,
                          s: 0,
                          partition_index: 3
                        }) <> <<5, 5, 5, 5, 5>>
                    },
                    %Buffer{
                      metadata: %{rtp: %{marker: true}},
                      payload:
                        PayloadDescriptor.serialize(%PayloadDescriptor{
                          x: 0,
                          n: 0,
                          s: 0,
                          partition_index: 4
                        }) <> <<5, 5, 5, 5, 5>>
                    }
                  ]},
               redemand: :output
             ]},
            payloader_state} ==
             Payloader.handle_process(:input, input_buffer, nil, payloader_state)
  end
end
