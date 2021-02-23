defmodule Membrane.RTP.VP8.PayloaderTest do
  use ExUnit.Case

  alias Membrane.RTP.VP8.{Payloader, FrameHeader}
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

    partition0 =
      <<80, 1, 0, 157, 1, 42, 10, 0, 10, 0, 21, 82, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 5,
        0, 0>>

    partition1 = <<5, 5, 5, 5, 5>>
    partition2 = <<5, 5, 5, 5, 5>>
    partition3 = <<5, 5, 5, 5, 5>>
    partition4 = <<5, 5, 5, 5, 5>>

    frame = partition0 <> partition1 <> partition2 <> partition3 <> partition4

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
                        }) <> <<80, 1, 0, 157, 1>>
                    },
                    %Buffer{
                      metadata: %{rtp: %{marker: false}},
                      payload:
                        PayloadDescriptor.serialize(%PayloadDescriptor{
                          x: 0,
                          n: 0,
                          s: 0,
                          partition_index: 0
                        }) <> <<42, 10, 0, 10, 0>>
                    },
                    %Buffer{
                      metadata: %{rtp: %{marker: false}},
                      payload:
                        PayloadDescriptor.serialize(%PayloadDescriptor{
                          x: 0,
                          n: 0,
                          s: 0,
                          partition_index: 0
                        }) <> <<21, 82, 0, 0, 0>>
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
                        }) <> <<5, 0, 0, 5, 0>>
                    },
                    %Buffer{
                      metadata: %{rtp: %{marker: false}},
                      payload:
                        PayloadDescriptor.serialize(%PayloadDescriptor{
                          x: 0,
                          n: 0,
                          s: 0,
                          partition_index: 0
                        }) <> <<0, 5, 0, 0>>
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

  test "advanced payloading test or real VP8 frame" do
    {:ok, file} = File.open("./test/results/input_vp8.dump", [:read])
    [frame1, frame2, frame3 | _rest] = :erlang.binary_to_term(IO.binread(file, :all))

    {:ok, payloader_state} = Payloader.handle_init(%Payloader{fragmentation_method: :advanced})

    assert {{:ok, _actions}, _state} =
             Payloader.handle_process(:input, frame3, nil, payloader_state)

    # IO.inspect(interframe)
    # assert {{:ok, _actions}, _state} = Payloader.handle_process(:input, keyframe, nil, payloader_state)
    # frames |> Enum.each(&(assert {{:ok, _actions}, _state} = Payloader.handle_process(:input, &1, nil, payloader_state)))
  end
end
