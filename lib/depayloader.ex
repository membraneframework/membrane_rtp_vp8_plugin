defmodule Membrane.RTP.VP8.Depayloader do
  @moduledoc """
  Depayloads VP8 frames from RTP packets according to: https://tools.ietf.org/html/rfc7741
  """

  use Membrane.Filter

  require Membrane.Logger

  alias Membrane.RTP.VP8.Frame
  alias Membrane.{Buffer, RemoteStream, RTP}
  alias Membrane.Event.Discontinuity
  alias Membrane.VP8

  @type sequence_number :: 0..65_535

  def_output_pad :output, caps: {RemoteStream, content_format: VP8, type: :packetized}

  def_input_pad :input, caps: RTP, demand_unit: :buffers

  defmodule State do
    @moduledoc false

    @type t :: %__MODULE__{
            frame_acc: Frame.t(),
            first_buffer: nil | Buffer.t()
          }
    defstruct frame_acc: %Frame{}, first_buffer: nil
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
    do: {{:ok, forward: event}, %State{state | frame_acc: %Frame{}}}

  @impl true
  def handle_end_of_stream(:input, _ctx, %State{first_buffer: nil} = state) do
    {{:ok, end_of_stream: :output}, state}
  end

  @impl true
  def handle_end_of_stream(:input, _ctx, state) do
    {frame, _acc} = Frame.flush(state.frame_acc)

    {{:ok,
      [
        buffer: {:output, %Buffer{state.first_buffer | payload: frame}},
        end_of_stream: :output
      ]}, %State{}}
  end

  @impl true
  def handle_process(:input, buffer, _ctx, state) do
    state = %{state | first_buffer: state.first_buffer || buffer}

    case parse_buffer(buffer, state) do
      {{:ok, actions}, new_state} ->
        {{:ok, actions ++ [redemand: :output]}, new_state}

      {:error, reason} ->
        log_malformed_buffer(buffer, reason)
        {{:ok, redemand: :output}, %State{}}
    end
  end

  defp parse_buffer(buffer, state) do
    case Frame.parse(buffer, state.frame_acc) do
      {:ok, :incomplete, acc} ->
        {{:ok, []}, %State{state | frame_acc: acc}}

      {:ok, frame, acc} ->
        {{:ok, [buffer: {:output, %{state.first_buffer | payload: frame}}]},
         %State{state | frame_acc: acc, first_buffer: buffer}}

      {:error, _} = error ->
        error
    end
  end

  defp log_malformed_buffer(packet, reason) do
    Membrane.Logger.warn("""
    An error occurred while parsing RTP packet.
    Reason: #{reason}
    Packet: #{inspect(packet, limit: :infinity)}
    """)
  end
end
