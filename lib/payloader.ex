defmodule Membrane.RTP.VP8.Payloader do
  @moduledoc """
  TODO
  """

  use Membrane.Filter

  alias Membrane.Caps.VP8
  alias Membrane.{Buffer, RemoteStream, RTP}
  alias Membrane.RTP.VP8.FrameHeader

  def_options max_payload_size: [
                spec: non_neg_integer(),
                default: 1400,
                description: """
                Maximal size of outputted payloads in bytes. RTP packet will contain VP8 payload descriptor which can have max: 6B.
                The resulting RTP packet will also RTP header (min 12B). After adding UDP header (8B), IPv4 header(min 20B, max 60B)
                everything should fit in standard MTU size (1500B)
                """
              ],
              fragmentation_method: [
                spec: :simple | :advanced,
                default: :simple,
                description: """
                If :simple passed payloader doesn't take into account boundaries of frame partitions.
                When :advanced is used, a single RTP packet carries data from one and only one partition.
                """
              ],
              payload_descriptor_type: [
                spec: :simple,
                default: :simple,
                description: """
                When set to :simple payloader will generate only minimal payload descriptors required for defragmentation.
                More complex payload descriptors are not yet supported so this option should be left as default.
                """
              ]

  def_output_pad :output, caps: RTP

  def_input_pad :input,
    caps: {RemoteStream, content_format: VP8, type: :packetized},
    demand_unit: :buffers

  defmodule State do
    @moduledoc false
    defstruct [
      :max_payload_size,
      :fragmentation_method
    ]
  end

  @impl true
  def handle_init(options), do: {:ok, Map.merge(%State{}, Map.from_struct(options))}

  @impl true
  def handle_caps(:input, _caps, _context, state) do
    {:ok, state}
  end

  @impl true
  def handle_prepared_to_playing(_ctx, state) do
    {{:ok, caps: {:output, %RTP{}}}, state}
  end

  @impl true
  def handle_demand(:output, size, :buffers, _ctx, state) do
    {{:ok, demand: {:input, size}}, state}
  end

  @impl true
  def handle_process(
        :input,
        buffer,
        _ctx,
        %State{fragmentation_method: :simple} = state
      ) do
    %Buffer{metadata: metadata, payload: payload} = buffer

    payloads = split_payload(payload, state.max_payload_size) |> add_descriptors(0)

    buffers = prepare_buffers(payloads, metadata)

    {{:ok, [buffer: {:output, buffers}, redemand: :output]}, state}
  end

  @impl true
  def handle_process(:input, buffer, _ctx, %State{fragmentation_method: :advanced} = state) do
    %Buffer{metadata: metadata, payload: payload} = buffer

    {:ok, frame_header} = FrameHeader.parse(payload)

    partitions = get_payloads(payload, frame_header.sizes)

    payloads =
      partitions
      |> Enum.with_index()
      |> Enum.flat_map(fn {partition, partition_index} ->
        partition |> split_payload(state.max_payload_size) |> add_descriptors(partition_index)
      end)

    buffers = prepare_buffers(payloads, metadata)

    {{:ok, [buffer: {:output, buffers}, redemand: :output]}, state}
  end

  defp get_payloads(payload, sizes) do
    {partitions, last_partition} =
      sizes
      |> Enum.reduce({[], payload}, fn size, {partitions, rest} ->
        <<partition::binary-size(size), rest::binary()>> = rest
        {[partition | partitions], rest}
      end)

    Enum.reverse([last_partition | partitions])
  end

  defp prepare_buffers(payloads, metadata) do
    payloads
    |> Enum.map(
      &%Buffer{
        metadata: Bunch.Struct.put_in(metadata, [:rtp], %{marker: false}),
        payload: &1
      }
    )
    |> List.update_at(-1, &Bunch.Struct.put_in(&1, [:metadata, :rtp, :marker], true))
  end

  defp split_payload(payload, max_payload_size) do
    chunk_count = ceil(byte_size(payload) / max_payload_size)
    max_chunk_size = ceil(byte_size(payload) / chunk_count)

    {chunks, last_chunk} = payload |> Bunch.Binary.chunk_every_rem(max_chunk_size)
    if last_chunk == <<>>, do: chunks, else: chunks ++ [last_chunk]
  end

  defp add_descriptors(chunks, 0) do
    # s-bit set and partition index equal to 0
    first_fragment_descriptor = <<16>>
    # s-bit is 0 as well as partition index
    next_fragment_descriptor = <<0>>

    [first_chunk | rest] = chunks

    [first_fragment_descriptor <> first_chunk] ++
      Enum.map(rest, &(next_fragment_descriptor <> &1))
  end

  defp add_descriptors(chunks, partition_index) do
    descriptor = <<0::5, partition_index::3>>
    Enum.map(chunks, &(descriptor <> &1))
  end
end
