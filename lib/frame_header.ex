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
         {:ok, rest} <- skip_segmentation_data(rest),
         {:ok, rest} <- skip_filter_config(rest),
         {:ok, rest} <- skip_loop_filter_adj(rest),
         {:ok, {header_acc, _rest}} <- decode_partitions_count(rest, header_acc),
        #  {:ok, rest} <- skip_quant_indices(rest),
        #  {:ok, rest} <- skip_refresh_data(rest, header_acc),
        #  {:ok, rest} <- skip_token_prob_update(rest),
        #  {:ok, rest} <- skip_coeff_data(rest, header_acc),
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

  defp decode_width_height(frame, %__MODULE__{is_keyframe: false} = header_acc),
    do: {:ok, {header_acc, frame}}

  defp decode_width_height(frame, %__MODULE__{is_keyframe: true} = header_acc) do
    case frame do
      # start sequence is 0x9d, 0x01, 0x2a
      <<157, 1, 42, width::16-little, height::16-little, _colour_space::1, _clamping_type::1,
        rest::bitstring()>> ->
        {:ok, {%{header_acc | width: width, height: height}, rest}}

      _error ->
        {:errro, :unparsable_data}
    end
  end

  defp skip_segmentation_data(<<0::1, rest::bitstring()>>), do: {:ok, rest}

  defp skip_segmentation_data(<<1::1, data::bitstring()>>) do
    <<updata_mb_segmentation_map::1, update_segment_feature_data::1, rest::bitstring()>> = data

    rest =
      case update_segment_feature_data do
        1 ->
          <<_segment_feature_mode::1, rest::bitstring()>> = rest

          rest =
            1..4
            |> Enum.reduce(rest, fn _i, <<flag::1, rest::bitstring()>> ->
              case flag do
                1 ->
                  <<_quantizer_and_sign::8, rest::bitstring()>> = rest
                  rest

                0 ->
                  rest
              end
            end)

          1..4
          |> Enum.reduce(rest, fn _i, <<flag::1, rest::bitstring()>> ->
            case flag do
              1 ->
                <<_update_and_sign::7, rest::bitstring()>> = rest
                rest

              0 ->
                rest
            end
          end)

        0 ->
          rest
      end

    rest =
      case updata_mb_segmentation_map do
        1 ->
          1..3
          |> Enum.reduce(rest, fn _i, <<flag::1, rest::bitstring()>> ->
            case flag do
              1 ->
                <<_segment_probe::8, rest::bitstring()>> = rest
                rest

              0 ->
                rest
            end
          end)

        0 ->
          rest
      end

    {:ok, rest}
  end

  defp skip_filter_config(data) do
    <<_filter_config::10, rest::bitstring()>> = data
    {:ok, rest}
  end

  defp skip_loop_filter_adj(<<0::1, rest::bitstring()>>), do: {:ok, rest}

  defp skip_loop_filter_adj(<<1::1, data::bitstring()>>) do
    <<ref_lf_data_update::1, rest::bitstring()>> = data

    rest =
      case ref_lf_data_update do
        1 ->
          1..8
          |> Enum.reduce(rest, fn _i, <<flag::1, rest::bitstring()>> ->
            case flag do
              1 ->
                <<_magnitude_and_sign::7, rest::bitstring()>> = rest
                rest

              0 ->
                rest
            end
          end)

        0 ->
          rest
      end

    {:ok, rest}
  end

  defp decode_partitions_count(data, header_acc) do
    <<log2count::2, rest::bitstring()>> = data
    count = :math.pow(2, log2count) |> floor()

    {:ok,
     {
       %{
         header_acc
         | coefficient_partitions_count: count
       },
       rest
     }}
  end

  defp skip_quant_indices(data) do
    <<_y_ac_qi::7, y_dc_delta_present::1, rest::bitstring()>> = data

    rest =
      if y_dc_delta_present == 1 do
        <<_magnitude_sign::5, rest::bitstring()>> = rest
        rest
      else
        rest
      end

    <<y2_dc_delta_present::1, rest::bitstring()>> = rest

    rest =
      if y2_dc_delta_present == 1 do
        <<_magnitude_sign::5, rest::bitstring()>> = rest
        rest
      else
        rest
      end

    <<y2_ac_delta_present::1, rest::bitstring()>> = rest

    rest =
      if y2_ac_delta_present == 1 do
        <<_magnitude_sign::5, rest::bitstring()>> = rest
        rest
      else
        rest
      end

    <<uv_dc_delta_present::1, rest::bitstring()>> = rest

    rest =
      if uv_dc_delta_present == 1 do
        <<_magnitude_sign::5, rest::bitstring()>> = rest
        rest
      else
        rest
      end

    <<uv_ac_delta_present::1, rest::bitstring()>> = rest

    if uv_ac_delta_present == 1 do
      <<_magnitude_sign::5, rest::bitstring()>> = rest
      {:ok, rest}
    else
      {:ok, rest}
    end
  end

  defp skip_refresh_data(data, %__MODULE__{is_keyframe: true}) do
    <<_refresh_entropy_probs::1, rest::bitstring()>> = data

    {:ok, rest}
  end

  defp skip_refresh_data(data, %__MODULE__{is_keyframe: false}) do
    <<refresh_golden_frame::1, refresh_alternate_frame::1, rest::bitstring()>> = data

    rest =
      if refresh_golden_frame == 0 do
        <<_copy_buffer_to_golden::2, rest::bitstring()>> = rest
        rest
      else
        rest
      end

    rest =
      if refresh_alternate_frame == 0 do
        <<_copy_buffer_to_alternate::2, rest::bitstring()>> = rest
        rest
      else
        rest
      end

    # sign_bias_golden, sign_bias_alternate, refresh_entropy_probs, refresh_last
    <<_other_flags::4, rest::bitstring>> = rest

    {:ok, rest}
  end

  defp skip_token_prob_update(data) do
    rest =
      1..1056
      |> Enum.reduce(data, fn _i, <<coeff_prob_update_flag::1, rest::bitstring()>> ->
        case coeff_prob_update_flag do
          1 ->
            <<_coeff_prob::8, rest::bitstring()>> = rest
            rest

          0 ->
            rest
        end
      end)

    {:ok, rest}
  end

  defp skip_coeff_data(data, header_acc) do
    <<mb_no_skip_coeff::1, rest::bitstring>> = data

    rest =
      if mb_no_skip_coeff == 1 do
        <<_prob_skip_false::8, rest::bitstring()>> = rest
        rest
      else
        rest
      end

    rest =
      if not header_acc.is_keyframe do
        <<_prob_intra, _prob_last, _prob_gf, intra_16x16_prob_update_flag::1, rest::bitstring()>> =
          rest

        rest =
          if intra_16x16_prob_update_flag == 1 do
            <<_intra_16x16_probs::32, rest::bitstring()>> = rest
            rest
          else
            rest
          end

        <<intra_chroma_prob_update_flag::1, rest::bitstring()>> = rest

        rest =
          if intra_chroma_prob_update_flag == 1 do
            <<_intra_chroma_probs::24, rest::bitstring()>> = rest
            rest
          else
            rest
          end

        {:ok, rest} = skip_mv_prob_update(rest)

        rest
      end

    {:ok, rest}
  end

  defp skip_mv_prob_update(data) do
    rest =
      1..38
      |> Enum.reduce(data, fn _i, <<mv_prob_update_flag::1, rest::bitstring()>> ->
        case mv_prob_update_flag do
          1 ->
            <<_prob::7, rest::bitstring()>> = rest
            rest

          0 ->
            rest
        end
      end)

    {:ok, rest}
  end

  defp decode_partitions_sizes(data, header_acc) do
    [first_partition_size] = header_acc.sizes

    IO.inspect(first_partition_size, label: "###")

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
