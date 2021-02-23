defmodule Membrane.RTP.VP8.Depayloader do
  @moduledoc """
  Depayloads VP8 frames from RTP packets according to: https://tools.ietf.org/html/rfc7741
  """

  use Membrane.Filter
  use Membrane.Log

  alias Membrane.Caps.VP8
  alias Membrane.RTP.VP8.Frame
  alias Membrane.{Buffer, RemoteStream, RTP}
  alias Membrane.Event.Discontinuity

  @type sequence_number :: 0..65_535

  def_output_pad :output, caps: {RemoteStream, content_format: VP8, type: :packetized}

  def_input_pad :input, caps: RTP, demand_unit: :buffers

  defmodule State do
    @moduledoc false

    @type t :: %__MODULE__{
            frame_acc: Frame.t(),
            last_buffer_metadata: %{}
          }
    defstruct frame_acc: %Frame{}, last_buffer_metadata: %{}
  end

  @impl true
  def handle_init(_options), do: {:ok, %State{}}

  @impl true
  def handle_caps(:input, _caps, _context, state) do
    caps = %RemoteStream{content_format: VP8, type: :packetized}
    {{:ok, caps: {:output, caps}}, state}
  end

  @impl true
  def handle_demand(:output, size, :buffers, _ctx, state),
    do: {{:ok, demand: {:input, size}}, state}

  @impl true
  def handle_event(:input, %Discontinuity{} = event, _ctx, state),
    do: {{:ok, forward: event}, %State{state | frame_acc: nil}}

  @impl true
  def handle_process(
        :input,
        buffer,
        _ctx,
        state
      ) do
    with {{:ok, actions}, new_state} <- parse_buffer(buffer, state) do
      {{:ok, actions ++ [redemand: :output]},
       %{new_state | last_buffer_metadata: buffer.metadata}}
    else
      {:error, reason} ->
        log_malformed_buffer(buffer, reason)
        {{:ok, redemand: :output}, %State{}}
    end
  end

  @impl true
  def handle_end_of_stream(:input, _ctx, state) do
    {frame, _acc} = Frame.flush(state.frame_acc)

    {{:ok,
      [
        buffer: {:output, %Buffer{metadata: state.last_buffer_metadata, payload: frame}},
        end_of_stream: :output
      ]}, %State{}}
  end

  defp parse_buffer(buffer, state) do
    case Frame.parse(buffer, state.frame_acc) do
      {:ok, frame, acc} ->
        {{:ok,
          [buffer: {:output, %{buffer | payload: frame, metadata: state.last_buffer_metadata}}]},
         %State{state | frame_acc: acc}}

      {:incomplete, acc} ->
        {{:ok, []}, %State{state | frame_acc: acc}}

      {:error, _} = error ->
        error
    end
  end

  defp log_malformed_buffer(packet, reason) do
    warn("""
    An error occurred while parsing RTP packet.
    Reason: #{reason}
    Packet: #{inspect(packet, limit: :infinity)}
    """)
  end
end

