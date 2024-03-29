defmodule Membrane.RTP.VP8.DepayloaderTest do
  use ExUnit.Case

  alias Membrane.Buffer
  alias Membrane.RTP.VP8.Depayloader
  alias Membrane.RTP.VP8.Depayloader.State

  @doc """
  Two RTP buffers that adds up to one VP8 frame
  1:
         X R N S R  PID
        +-+-+-+-+-+-----+
        |0|0|0|1|0|0|0|0| (FIRST OCTET)
        +-+-+-+-+-+-+-+-+
        |1 0 1 0 1 0 1 0| (VP8 PAYLOAD)
        |1 0 1 0 1 0 1 1|
        +-+-+-+-+-+-+-+-+
  2:
         X R N S R  PID
        +-+-+-+-+-+-+-+-+
        |0|0|0|0|0|0|0|1| (FIRST OCTET)
        +-+-+-+-+-+-+-+-+
        |1 0 1 0 1 1 0 0| (VP8 PAYLOAD)
        |1 0 1 0 1 1 0 1|
        +-+-+-+-+-+-+-+-+
  """
  test "two rtp buffers carrying one vp8 frame" do
    buffer_1 = %Buffer{
      payload: <<16, 170, 171>>,
      metadata: %{rtp: %{sequence_number: 14_450, timestamp: 30}}
    }

    buffer_2 = %Buffer{
      payload: <<1, 172, 173>>,
      metadata: %{rtp: %{sequence_number: 14_451, timestamp: 30}}
    }

    {[], depayloader_state} = Depayloader.handle_init(nil, [])

    assert {[], depayloader_state} =
             Depayloader.handle_buffer(:input, buffer_1, nil, depayloader_state)

    assert {[], depayloader_state} =
             Depayloader.handle_buffer(:input, buffer_2, nil, depayloader_state)

    assert {[
              buffer:
                {:output,
                 %Buffer{
                   payload: <<170, 171, 172, 173>>,
                   metadata: %{rtp: %{sequence_number: 14_450, timestamp: 30}}
                 }},
              end_of_stream: :output
            ], %State{}} == Depayloader.handle_end_of_stream(:input, nil, depayloader_state)
  end

  @doc """
    one rtp buffer carrying one vp8 frame
    1:
         X R N S R  PID
        +-+-+-+-+-+-+-+-+
        |0|0|0|1|0|0|0|0| (FIRST OCTET)
        +-+-+-+-+-+-+-+-+
        |1 0 1 0 1 0 1 0| (VP8 PAYLOAD)
        |1 0 1 0 1 0 1 1|
        +-+-+-+-+-+-+-+-+
  """
  test "one rtp buffer carrying one vp8 frame" do
    buffer = %Buffer{
      payload: <<16, 170, 171>>,
      metadata: %{rtp: %{sequence_number: 14_450, timestamp: 30}}
    }

    {[], depayloader_state} = Depayloader.handle_init(nil, [])

    assert {[], depayloader_state} =
             Depayloader.handle_buffer(:input, buffer, nil, depayloader_state)

    assert {[
              buffer:
                {:output,
                 %Buffer{
                   metadata: %{rtp: %{sequence_number: 14_450}},
                   payload: <<170, 171>>
                 }},
              end_of_stream: :output
            ], %State{}} = Depayloader.handle_end_of_stream(:input, nil, depayloader_state)
  end

  @doc """
  Missing packet:
  1: (sequence number 14450)
         X R N S R  PID
        +-+-+-+-+-+-----+
        |0|0|0|1|0|0|0|0| (FIRST OCTET)
        +-+-+-+-+-+-+-+-+
        |1 0 1 0 1 0 1 0| (VP8 PAYLOAD)
        |1 0 1 0 1 0 1 1|
        +-+-+-+-+-+-+-+-+
  2: (sequence number 14452)
         X R N S R  PID
        +-+-+-+-+-+-+-+-+
        |0|0|0|0|0|0|0|1| (FIRST OCTET)
        +-+-+-+-+-+-+-+-+
        |1 0 1 0 1 1 0 0| (VP8 PAYLOAD)
        |1 0 1 0 1 1 0 1|
        +-+-+-+-+-+-+-+-+
  """
  test "missing packet" do
    buffer_1 = %Buffer{
      payload: <<16, 170, 171>>,
      metadata: %{rtp: %{sequence_number: 14_450, timestamp: 30}}
    }

    buffer_2 = %Buffer{
      payload: <<1, 172, 173>>,
      metadata: %{rtp: %{sequence_number: 14_452, timestamp: 30}}
    }

    {[], depayloader_state} = Depayloader.handle_init(nil, [])

    assert {[], depayloader_state} =
             Depayloader.handle_buffer(:input, buffer_1, nil, depayloader_state)

    assert {[], %State{}} = Depayloader.handle_buffer(:input, buffer_2, nil, depayloader_state)
  end

  @doc """
  Not equal timestamps:
  1: (sequence number 14450)
         X R N S R  PID
        +-+-+-+-+-+-----+
        |0|0|0|1|0|0|0|0| (FIRST OCTET)
        +-+-+-+-+-+-+-+-+
        |1 0 1 0 1 0 1 0| (VP8 PAYLOAD)
        |1 0 1 0 1 0 1 1|
        +-+-+-+-+-+-+-+-+
  2: (sequence number 14451)
         X R N S R  PID
        +-+-+-+-+-+-+-+-+
        |0|0|0|0|0|0|0|1| (FIRST OCTET)
        +-+-+-+-+-+-+-+-+
        |1 0 1 0 1 1 0 0| (VP8 PAYLOAD)
        |1 0 1 0 1 1 0 1|
        +-+-+-+-+-+-+-+-+
  """
  test "not equal timestamps" do
    buffer_1 = %Buffer{
      payload: <<16, 170, 171>>,
      metadata: %{rtp: %{sequence_number: 14_450, timestamp: 30}}
    }

    buffer_2 = %Buffer{
      payload: <<1, 172, 173>>,
      metadata: %{rtp: %{sequence_number: 14_451, timestamp: 31}}
    }

    {[], depayloader_state} = Depayloader.handle_init(nil, [])

    assert {[], depayloader_state} =
             Depayloader.handle_buffer(:input, buffer_1, nil, depayloader_state)

    assert {[], %State{}} = Depayloader.handle_buffer(:input, buffer_2, nil, depayloader_state)
  end
end
