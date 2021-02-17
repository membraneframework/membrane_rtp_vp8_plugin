defmodule Membrane.RTP.VP8.FrameHeader do
  @moduledoc """
  Each VP8 frame contains structure called frame header. Datailed description of this structure
  can be found here: https://tools.ietf.org/html/rfc6386#section-9.1

  Frame header contains informations useful mostly for decoding process but there are some details
  importatnt for packetization and parsing as well. This module provides utility to extract (as for now):
    * is keyframe
    * frame width and height
    * amount of data partitions and their offsets (required for advanced packetization)
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
         {:ok, {header_acc, rest}} <- decode_partitions_count(rest, header_acc),
         {:ok, {header_acc, _rest}} <- decode_partitions_sizes(rest, header_acc) do
      {:ok, header_acc}
    end
  end

  defp decode_frame_tag(<<frame_tag::binary-size(3), rest::bitstring()>>, header_acc) do
    <<size_0::3, _showframe_and_version::4, keyframe::1, size_1, size_2>> = frame_tag
    <<size::19>> = <<size_2, size_1, size_0::3>>

    {:ok, {%{header_acc | sizes: header_acc.sizes ++ [size], is_keyframe: keyframe == 0}, rest}}
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

      _ ->
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

                _ ->
                  rest
              end
            end)

          1..4
          |> Enum.reduce(rest, fn _i, <<flag::1, rest::bitstring()>> ->
            case flag do
              1 ->
                <<_update_and_sign::7, rest::bitstring()>> = rest
                rest

              _ ->
                rest
            end
          end)

        _ ->
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

              _ ->
                rest
            end
          end)

        _ ->
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

              _ ->
                rest
            end
          end)

        _ ->
          rest
      end

    {:ok, rest}
  end

  defp decode_partitions_count(data, header_acc) do
    <<count::2, rest::bitstring()>> = data

    {:ok, {%{header_acc | coefficient_partitions_count: floor(:math.pow(2, count))}, rest}}
  end

  defp decode_partitions_sizes(data, header_acc) do
    [first_partition_size] = header_acc.sizes
    bit_size = 8 * first_partition_size
    <<_first_partition::size(bit_size), data::bitstring()>> = data

    {sizes, rest} =
      if header_acc.coefficient_partitions_count > 1 do
        1..(header_acc.coefficient_partitions_count - 1)
        |> Enum.map_reduce(data, fn _i, acc ->
          <<size::24-little, rest::bitstring()>> = acc
          {size, rest}
        end)
      else
        {[], data}
      end

    {:ok, {%{header_acc | sizes: header_acc.sizes ++ sizes}, rest}}
  end
end
