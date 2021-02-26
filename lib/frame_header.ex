defmodule Membrane.RTP.VP8.FrameHeader do
  @moduledoc """
  Each VP8 frame contains structure called frame header. Datailed description of this structure
  can be found here: https://tools.ietf.org/html/rfc6386#section-9.1

  Frame header contains informations useful mostly for decoding process but there are some details
  importatnt for packetization and parsing as well. This module provides utility to extract (as for now):
    * is keyframe
    * frame width and height
    * amount of data partitions and their offsets (required for advanced packetization)

    Frame tag (24 bit):
    +-+-+-+-+---+-+-------------+-------------+
    |size0|s|ver|f|    size1    |    size2    | : s - show frame, ver - version, f - keyframe(0 -> KEYFRAME, 1 -> INTERFRAME)
    +-----+-+---+-+-------------+-------------+

    if (keyframe):
      start sequence (24 bit):
      +-------------+-------------+-------------+
      |    0x9d     |    0x01     |     0x2a    |
      +-------------+-------------+-------------+
      diemnsions(2x 16 bit):
      +-------------+-------------+-------------+-------------+
      |           width           |           height          |
      +-------------+-------------+-------------+-------------+
      colour space(1 bit) and clamping type(1 bit):
      +-+-+
      |s|t|
      +-+-+

    +-+
    |e| : e - segmentation_enabled (1 bit)
    +-+

    if (segmentation_enabled)
      update_mb_segmentation_map (1 bit) and update_segment_feature_data (1 bit)
      +-+-+
      |m|d| : m - update_mb_segmentation_map, d - update_segment_feature_data
      +-+-+

      if (update_segment_feature_data)
        +-+
        |m| : m - segment_feature_mode (1 bit)
        +-+
        +-+             +-------------+-+                                                \
        |f| if (f == 1) |  quantizer  |s| : f - flag (1 bit), quantizer and sign (7 bit)  |- 4x
        +-+             +-------------+-+                                                /

        +-+             +-----------+-+                                                  \
        |f| if (f == 1) | lf update |s| : f - flag (1 bit), quantizer and sign (6 bit)    |- 4x
        +-+             +-----------+-+                                                  /

      if (update_mb_segmentation_map)
        +-+             +----------------+                                               \
        |f| if (f == 1) |  segment_probe | : f - flag (1 bit), segment probe - (8 bit)    |- 3x
        +-+             +----------------+                                               /

    +------------------------------------------+
    |filter type, loop filter, sharpness level | - 10 bit
    +------------------------------------------+

    +-+
    |e| : e - loop_filter_adj_enabled (1 bit)
    +-+

    if (loop_filter_adj_enabled)
      +-+
      |m| : m - mode_ref_lf_data_update (1 bit)
      +-+
      if (mode_ref_lf_data_update)
        +-+             +-----------+-+                                     \
        |f| if (f == 1) | magnitude |s| : magnitude (6 bit) s - sign (1 bit) |- 8x
        +-+             +-----------+-+                                     /

    +--+
    |lg| : lg - log2(coefficient partitions count) (2bit)
    +--+

                            .
                            .  rest of first partition (size of first partition can be calculated form size0 size1 size2)
                            .

    +------------------------+            \
    |    partition size      | : (24 bit)  |- (coefficient partitions count - 1)x
    +------------------------+            /
  """

  alias Membrane.RTP.VP8.BooleanDecoder

  @type t :: %__MODULE__{
          is_keyframe: boolean(),
          coefficient_partitions_count: non_neg_integer(),
          width: non_neg_integer(),
          height: non_neg_integer(),
          sizes: [non_neg_integer()]
        }

  defstruct [:is_keyframe, :coefficient_partitions_count, :width, :height, sizes: []]

  @spec parse(bitstring()) :: {:ok, t()} | {:error, :unparsable_data}
  def parse(frame) do
    with {:ok, {header_acc, rest}} <- decode_frame_tag(frame, %__MODULE__{}),
         {:ok, {header_acc, rest}} <- decode_width_height(rest, header_acc),
         <<header::binary-size(92), _rest::bitstring()>> <- rest,
         {:ok, decoder_state} <- BooleanDecoder.init_bool_decoder(header),
         {:ok, decoder_state} <- skip_colour_space_and_clamping_type(decoder_state),
         {:ok, decoder_state} <- skip_segmentation_data(decoder_state),
         {:ok, decoder_state} <- skip_filter_config(decoder_state),
         {:ok, decoder_state} <- skip_loop_filter_adj(decoder_state),
         {:ok, header_acc} <- decode_partitions_count(decoder_state, header_acc),
         {:ok, {header_acc, _rest}} <- decode_partitions_sizes(frame, header_acc) do
      {:ok, header_acc}
    end
  end

  defp decode_frame_tag(<<frame_tag::binary-size(3), rest::bitstring()>>, header_acc) do
    <<size_0::3, _showframe_and_version::4, keyframe::1, size_1, size_2>> = frame_tag
    <<size::19>> = <<size_2, size_1, size_0::3>>

    size = if keyframe == 0, do: size + 10, else: size + 3

    {:ok, {%{header_acc | sizes: [size], is_keyframe: keyframe == 0}, rest}}
  end

  defp decode_frame_tag(_frame, _acc), do: {:error, :unparsable_data}

  defp decode_width_height(frame, %__MODULE__{is_keyframe: false} = header_acc) do
    {:ok, {header_acc, frame}}
  end

  defp decode_width_height(frame, %__MODULE__{is_keyframe: true} = header_acc) do
    case frame do
      # start sequence is 0x9d, 0x01, 0x2a
      <<157, 1, 42, width::16-little, height::16-little, rest::binary()>> ->
        {:ok, {%{header_acc | width: width, height: height}, rest}}

      _error ->
        {:errro, :unparsable_data}
    end
  end

  defp skip_colour_space_and_clamping_type(bool_decoder) do
    {:ok, {_colour_space, bool_decoder}} = BooleanDecoder.read_bool(128, bool_decoder)
    {:ok, {_clamping_type, bool_decoder}} = BooleanDecoder.read_bool(128, bool_decoder)

    {:ok, bool_decoder}
  end

  defp skip_segmentation_data(bool_decoder) do
    {:ok, {flag, bool_decoder}} = BooleanDecoder.read_bool(128, bool_decoder)

    case flag do
      1 ->
        {:ok, {updata_mb_segmentation_map, bool_decoder}} =
          BooleanDecoder.read_bool(128, bool_decoder)

        {:ok, {update_segment_feature_data, bool_decoder}} =
          BooleanDecoder.read_bool(128, bool_decoder)

        bool_decoder = skip_segment_feature_data(update_segment_feature_data, bool_decoder)
        bool_decoder = skip_update_mb_segmentation_map(updata_mb_segmentation_map, bool_decoder)
        {:ok, bool_decoder}

      0 ->
        {:ok, bool_decoder}
    end
  end

  defp skip_segment_feature_data(0, bool_decoder), do: bool_decoder

  defp skip_segment_feature_data(1, bool_decoder) do
    {:ok, {_segment_feature_mode, bool_decoder}} = BooleanDecoder.read_bool(128, bool_decoder)

    bool_decoder =
      1..4
      |> Enum.reduce(bool_decoder, fn _i, bool_decoder ->
        {:ok, {flag, bool_decoder}} = BooleanDecoder.read_bool(128, bool_decoder)

        case flag do
          1 ->
            {:ok, {_v, bool_decoder}} = BooleanDecoder.read_literal(8, bool_decoder)
            bool_decoder

          0 ->
            bool_decoder
        end
      end)

    1..4
    |> Enum.reduce(bool_decoder, fn _i, bool_decoder ->
      {:ok, {flag, bool_decoder}} = BooleanDecoder.read_bool(128, bool_decoder)

      case flag do
        1 ->
          {:ok, {_v, bool_decoder}} = BooleanDecoder.read_literal(7, bool_decoder)
          bool_decoder

        0 ->
          bool_decoder
      end
    end)
  end

  defp skip_update_mb_segmentation_map(0, bool_decoder), do: bool_decoder

  defp skip_update_mb_segmentation_map(1, bool_decoder) do
    1..3
    |> Enum.reduce(bool_decoder, fn _i, bool_decoder ->
      {:ok, {flag, bool_decoder}} = BooleanDecoder.read_bool(128, bool_decoder)

      case flag do
        1 ->
          {:ok, {_v, bool_decoder}} = BooleanDecoder.read_literal(8, bool_decoder)
          bool_decoder

        0 ->
          bool_decoder
      end
    end)
  end

  defp skip_filter_config(bool_decoder) do
    {:ok, {_v, bool_decoder}} = BooleanDecoder.read_literal(1, bool_decoder)
    {:ok, {_v, bool_decoder}} = BooleanDecoder.read_literal(6, bool_decoder)
    {:ok, {_v, bool_decoder}} = BooleanDecoder.read_literal(3, bool_decoder)
    {:ok, bool_decoder}
  end

  defp skip_loop_filter_adj(bool_decoder) do
    {:ok, {loop_filter_adj_enabled, bool_decoder}} = BooleanDecoder.read_bool(128, bool_decoder)

    bool_decoder = skip_lf_delta_update(loop_filter_adj_enabled, bool_decoder)

    {:ok, bool_decoder}
  end

  defp skip_lf_delta_update(0, bool_decoder), do: bool_decoder

  defp skip_lf_delta_update(1, bool_decoder) do
    {:ok, {ref_lf_data_update, bool_decoder}} = BooleanDecoder.read_bool(128, bool_decoder)

    case ref_lf_data_update do
      1 ->
        1..8
        |> Enum.reduce(bool_decoder, fn _i, bool_decoder ->
          {:ok, {flag, bool_decoder}} = BooleanDecoder.read_bool(128, bool_decoder)

          case flag do
            1 ->
              {:ok, {_v, bool_decoder}} = BooleanDecoder.read_literal(7, bool_decoder)
              bool_decoder

            0 ->
              bool_decoder
          end
        end)

      0 ->
        bool_decoder
    end
  end

  defp decode_partitions_count(bool_decoder, header_acc) do
    {:ok, {log2count, _bool_decoder}} = BooleanDecoder.read_literal(2, bool_decoder)
    count = :math.pow(2, log2count) |> floor()

    {:ok,
     %{
       header_acc
       | coefficient_partitions_count: count
     }}
  end

  defp decode_partitions_sizes(data, header_acc) do
    [first_partition_size] = header_acc.sizes

    IO.inspect(byte_size(data))
    IO.inspect(first_partition_size)

    <<_first_partition::binary-size(first_partition_size), data::bitstring()>> = data

    {sizes, rest} =
      if header_acc.coefficient_partitions_count > 1 do
        1..(header_acc.coefficient_partitions_count - 1)
        |> Enum.map_reduce(data, fn _i, acc ->
          <<size::little-24, rest::bitstring()>> = acc
          {size, rest}
        end)
      else
        {[], data}
      end

    first_partition_size =
      first_partition_size + 3 * (header_acc.coefficient_partitions_count - 1)

    {:ok, {%{header_acc | sizes: [first_partition_size] ++ sizes}, rest}}
  end
end
