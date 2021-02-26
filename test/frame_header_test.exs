defmodule Membrane.RTP.VP8.FrameHeaderTest do
  use ExUnit.Case
  alias Membrane.RTP.VP8.FrameHeader

  describe "VP8 frame header parsing tests" do
    @doc """
      key_frame: true
      start sequence: present,
      width: 10,
      height: 10,
      sizes: [20+9, 5, 5, 5]
    """
    test "example keyframe with 4 coefficient partitions" do
      example_frame =
        <<80, 1, 0, 157, 1, 42, 10, 0, 10, 0, 21, 82, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 5,
          0, 0, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5>>

      expected_frame_header = %FrameHeader{
        is_keyframe: true,
        coefficient_partitions_count: 4,
        width: 10,
        height: 10,
        sizes: [29, 5, 5, 5]
      }

      {:ok, actual_header} = FrameHeader.parse(example_frame)

      assert expected_frame_header == actual_header
    end

    test "example interframeframe with 4 coefficient partitions" do
      example_frame =
        <<49, 2, 0, 0, 8, 42, 10, 0, 10, 0, 21, 82, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 5,
          0, 0, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5>>

      expected_frame_header = %FrameHeader{
        is_keyframe: false,
        coefficient_partitions_count: 4,
        width: nil,
        height: nil,
        sizes: [29, 5, 5, 5]
      }

      {:ok, actual_header} = FrameHeader.parse(example_frame)

      assert expected_frame_header == actual_header
    end
  end
end
