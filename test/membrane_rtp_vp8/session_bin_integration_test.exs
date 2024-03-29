defmodule Membrane.RTP.VP8.SessionBinIntegrationTest do
  use ExUnit.Case

  import Membrane.ChildrenSpec
  import Membrane.Testing.Assertions

  require Membrane.Pad, as: Pad

  alias Membrane.Element.IVF
  alias Membrane.RTP
  alias Membrane.Testing

  @moduletag :tmp_dir

  @ivf_reference_file "./test/fixtures/input_vp8.ivf"
  @ivf_result_file "result.ivf"

  @rtp_input %{
    pcap: "test/fixtures/input_vp8.pcap",
    video: %{ssrc: 1_660_289_535, frames_n: 300, width: 1080, height: 720}
  }

  @fmt_mapping %{96 => {:VP8, 90_000}}

  test "depayloading rtp with vp8", %{tmp_dir: tmp_dir} do
    defmodule TestPipeline do
      use Membrane.Pipeline

      @impl true
      def handle_init(_ctx, options) do
        spec =
          child(:pcap, %Membrane.Pcap.Source{path: options.input.pcap})
          |> via_in(:rtp_input)
          |> child(:rtp, %RTP.SessionBin{fmt_mapping: options.fmt_mapping})

        {[spec: spec], %{result_file: options.result_file, video: options.input.video}}
      end

      @impl true
      def handle_child_notification(
            {:new_rtp_stream, ssrc, _pt, _extensions},
            :rtp,
            _ctx,
            %{result_file: result_file, video: video} = state
          ) do
        spec =
          get_child(:rtp)
          |> via_out(Pad.ref(:output, ssrc), options: [depayloader: Membrane.RTP.VP8.Depayloader])
          |> child(
            {:ivf_writer, ssrc},
            %IVF.Serializer{width: video.width, height: video.height, scale: 1, rate: 30}
          )
          |> child({:file_sink, ssrc}, %Membrane.File.Sink{location: result_file})

        {[spec: spec], state}
      end

      @impl true
      def handle_child_notification(_notification, _child, _ctx, state) do
        {:ok, state}
      end
    end

    result_file = Path.join(tmp_dir, @ivf_result_file)

    pipeline =
      Testing.Pipeline.start_link_supervised!(
        module: TestPipeline,
        custom_args: %{
          input: @rtp_input,
          result_file: result_file,
          fmt_mapping: @fmt_mapping
        }
      )

    %{video: %{ssrc: video_ssrc}} = @rtp_input

    assert_start_of_stream(pipeline, {:file_sink, ^video_ssrc})

    assert_end_of_stream(pipeline, {:file_sink, ^video_ssrc}, :input, 4000)

    assert File.read!(result_file) == File.read!(@ivf_reference_file)

    Testing.Pipeline.terminate(pipeline)
  end

  defmodule NoopFilter do
    use Membrane.Filter
    def_input_pad :input, accepted_format: _any
    def_output_pad :output, accepted_format: _any

    @impl true
    def handle_buffer(:input, buffer, _ctx, state) do
      {[buffer: {:output, buffer}], state}
    end
  end

  test "payloading and depayloading back", %{tmp_dir: tmp_dir} do
    pipeline =
      Testing.Pipeline.start_link_supervised!(
        spec:
          child(:source, %Membrane.File.Source{location: @ivf_reference_file})
          |> child(:deserializer, IVF.Deserializer)
          |> via_in(Pad.ref(:input, 1234), options: [payloader: RTP.VP8.Payloader])
          |> child(:session_bin, %RTP.SessionBin{fmt_mapping: @fmt_mapping})
          |> via_out(Pad.ref(:rtp_output, 1234), options: [encoding: :VP8])
          # not to link session bin with itself
          |> child(:noop, NoopFilter)
          |> via_in(Pad.ref(:rtp_input, 2137))
          |> get_child(:session_bin)
      )

    assert_pipeline_notified(pipeline, :session_bin, {:new_rtp_stream, ssrc, _pt, _extensions})

    result_file = Path.join(tmp_dir, @ivf_result_file)

    Testing.Pipeline.execute_actions(pipeline,
      spec: [
        get_child(:session_bin)
        |> via_out(Pad.ref(:output, ssrc), options: [depayloader: Membrane.RTP.VP8.Depayloader])
        |> child(:ivf_writer, %IVF.Serializer{
          width: @rtp_input.video.width,
          height: @rtp_input.video.height,
          scale: 1,
          rate: 30
        })
        |> child(:sink, %Membrane.File.Sink{location: result_file})
      ]
    )

    assert_end_of_stream(pipeline, :sink, :input, 4000)

    assert File.read!(result_file) == File.read!(@ivf_reference_file)
    Testing.Pipeline.terminate(pipeline)
  end
end
