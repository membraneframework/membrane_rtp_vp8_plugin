defmodule Membrane.RTP.VP8.FrameHeaderTest do
  use ExUnit.Case
  alias Membrane.RTP.VP8.FrameHeader

  describe "VP8 frame header parsing tests" do
    @doc """
      frame tag (10B): 100_00000 2 0 0x9d 0x01 0x2a 10 0 0 10 0 0 -> first partition lenght: 20, keyframe: true, dim: 10x10,
      colour_space and clamping type (2b): 10,
      segmentation enabled (1b): 1,
      update_mb_segmentation_map (1b): 0,
      update_segment_feature_data (1b): 1,
      segment_feature_mode (1b): 0,
      quantizer update (12b): 1_01010101
                              0
                              0
                              1_01010101
      loop filter update (11b): 0
                                0
                                0
                                1_0101010
      filter type (1b), filter level (6b), sharpness level (3b): 0_000000_111
      loop_filter_adj_enabled (1b): 0,
      log2(partition count) (2b): 10,
      padding to 20bytes,
      coefficient partitions sizes (9B): 5 0 0, 5 0 0, 5 0 0
    """
    test "example keyframe with 4 coefficient partitions" do
      example_frame =
        <<128, 2, 0, 157, 1, 42, 10, 0, 10, 0, 170, 85, 0, 154, 197, 110, 99, 0, 0, 0, 0, 0, 0, 0,
          0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 5, 0, 0, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5,
          5, 5, 5, 5, 5, 5>>

      expected_frame_header = %FrameHeader{
        is_keyframe: true,
        coefficient_partitions_count: 4,
        width: 10,
        height: 10,
        sizes: [39, 5, 5, 5]
      }

      {:ok, actual_header} = FrameHeader.parse(example_frame)

      assert expected_frame_header == actual_header
    end

    @doc """
      frame tag (10B): 100_00001 2 0 -> first partition lenght: 20, keyframe: false,
      colour_space and clamping type (2b): 10,
      segmentation enabled (1b): 0,
      filter type (1b), filter level (6b), sharpness level (3b): 0_000000_111
      loop_filter_adj_enabled (1b): 1,
      delta update (1b): 1,
      updates (22b): 1_0000000
                     0
                     0
                     0
                     0
                     0
                     0
                     1_1111111
      log2(partition count) (2b): 10,
      padding to 20bytes,
      coefficient partitions sizes (9B): 5 0 0, 5 0 0, 5 0 0
    """
    test "example interframeframe with 4 coefficient partitions" do
      example_frame =
        <<129, 2, 0, 128, 62, 130, 7, 236, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0,
          5, 0, 0, 5, 0, 0, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5>>

      expected_frame_header = %FrameHeader{
        is_keyframe: false,
        coefficient_partitions_count: 4,
        width: nil,
        height: nil,
        sizes: [32, 5, 5, 5]
      }

      {:ok, actual_header} = FrameHeader.parse(example_frame)

      assert expected_frame_header == actual_header
    end
  end
end
