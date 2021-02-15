defmodule Membrane.RTP.VP8.FramePartitions do
  @moduledoc """
  This module provides functions to extract VP8 partitions from frame. For the purpose of fragmentation during payloading
  we are interested only in amount of partitions in the frame and their sizes. To extract this information we need to read:
    * header size - (it can be extracted from first three bytes of header)
    * amount of partitions - (amount = 2 to the power of (value represented by last two bits of frame header))
    * partitions sizes - (just after the frame header there are (amount of partitions - 1) sizes written on 3 bytes chunks,
                          as we can notice size of last partition is not necessary for the purpose of fragmentation).

  As for now module struct will contain only list of partition sizes and offsets - it is enough for framentation. In the future struct
  can be extended to conatin for example width and height of frame as this informations are also contained in the frame header.
  """

  @spec get_partitions(binary()) :: [binary()]
  def get_partitions(frame) do
    with {:ok, {header, rest}} <- get_header(frame),
         {:ok, {partition0, partitions_sizes, rest}} <-
           get_partitions_sizes_and_partition0(header, rest),
         {:ok, partitions} <- get_rest_of_partitions(partitions_sizes, rest) do
      [partition0 | partitions]
    end
  end

  defp get_header(<<size0::3, _sf_v::4, key_frame::1, size1, size2, _rest::binary()>> = frame) do
    <<size_of_header::19>> = <<size2, size1, size0::3>>

    size_of_header = if key_frame == 1, do: size_of_header + 10, else: size_of_header + 3
    <<header::binary-size(size_of_header), rest::binary()>> = frame

    {:ok, {header, rest}}
  end

  defp get_partitions_sizes_and_partition0(header, rest) do
    last_byte = <<:binary.last(header)>>
    <<_unused::6, partitions_amount_exponent::2>> = last_byte

    partitions_count = :math.pow(2, partitions_amount_exponent) |> floor()

    c = (partitions_count - 1) * 3

    <<partitions_bin::binary-size(c), rest::binary()>> = rest

    partitions_sizes =
      Bunch.Binary.chunk_every(partitions_bin, 3)
      |> Enum.map(fn size_bin ->
        <<size::24-little>> = size_bin
        size
      end)

    partition0 = header <> partitions_bin

    {:ok, {partition0, partitions_sizes, rest}}
  end

  @spec get_rest_of_partitions(any, any) :: {:ok, list}
  def get_rest_of_partitions(partitions_sizes, rest) do
    {partitions, last_partition} =
      partitions_sizes
      |> Enum.reduce({[], rest}, fn size, {partitions, rest} ->
        <<partition::binary-size(size), rest::binary()>> = rest
        {[partition | partitions], rest}
      end)

    {:ok, Enum.reverse([last_partition | partitions])}
  end
end
