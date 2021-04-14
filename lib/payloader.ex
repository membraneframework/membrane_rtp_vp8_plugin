defmodule Membrane.RTP.VP8.Payloader do
  @moduledoc """
  TODO
  """

  use Membrane.Filter

  alias Membrane.Caps.VP8
  alias Membrane.{Buffer, RemoteStream, RTP}

  # s-bit set and partition index equal to 0
  @first_fragment_descriptor <<16>>

  # s-bit is 0 as well as partition index
  @following_fragment_descriptor <<0>>

  def_options max_payload_size: [
                spec: non_neg_integer(),
                default: 1400,
                description: """
                Maximal size of outputted payloads in bytes. RTP packet will contain VP8 payload descriptor which can have max: 6B.
                The resulting RTP packet will also RTP header (min 12B). After adding UDP header (8B), IPv4 header(min 20B, max 60B)
                everything should fit in standard MTU size (1500B)
                """
              ],
              payload_descriptor_type: [
                spec: :simple,
                default: :simple,
                description: """
                When set to :simple payloader will generate only minimal payload descriptors required for fragmentation.
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
      :max_payload_size
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
        state
      ) do
    %Buffer{metadata: metadata, payload: payload} = buffer
    chunk_count = ceil(byte_size(payload) / state.max_payload_size)
    max_chunk_size = ceil(byte_size(payload) / chunk_count)

    buffers =
      payload
      |> Bunch.Binary.chunk_every_rem(max_chunk_size)
      |> add_descriptors()
      |> Enum.map(
        &%Buffer{
          metadata: Bunch.Struct.put_in(metadata, [:rtp], %{marker: false}),
          payload: &1
        }
      )
      |> List.update_at(-1, &Bunch.Struct.put_in(&1, [:metadata, :rtp, :marker], true))

    {{:ok, [buffer: {:output, buffers}, redemand: :output]}, state}
  end

  defp add_descriptors({chunks, last_chunk}) do
    chunks = if byte_size(last_chunk) > 0, do: chunks ++ [last_chunk], else: chunks

    [first_chunk | rest] = chunks

    [@first_fragment_descriptor <> first_chunk] ++
      Enum.map(rest, &(@following_fragment_descriptor <> &1))
  end
end
