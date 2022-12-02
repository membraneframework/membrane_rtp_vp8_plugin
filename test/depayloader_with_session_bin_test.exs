defmodule Membrane.RTP.VP8.DepayloaderWithSessionBinTest do
  use ExUnit.Case

  import Membrane.Testing.Assertions

  alias Membrane.Element.IVF
  alias Membrane.RTP
  alias Membrane.Testing

  @results_dir "./test/results"
  @ivf_result_file @results_dir <> "/result.ivf"
  @ivf_reference_file "./test/fixtures/input_vp8.ivf"

  @rtp_input %{
    pcap: "test/fixtures/input_vp8.pcap",
    video: %{ssrc: 1_660_289_535, frames_n: 300, width: 1080, height: 720}
  }

  @fmt_mapping %{96 => {:VP8, 90_000}}

  defmodule TestPipeline do
    use Membrane.Pipeline

    @impl true
    def handle_init(_ctx, options) do
      spec =
        child(:pcap, %Membrane.Pcap.Source{path: options.input.pcap})
        |> via_in(:rtp_input)
        |> child(:rtp, %RTP.SessionBin{fmt_mapping: options.fmt_mapping})

      {[spec: spec, playback: :playing],
       %{:result_file => options.result_file, :video => options.input.video}}
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

  test "depayloading rtp with vp8" do
    test_stream(@rtp_input, @ivf_result_file)
  end

  defp test_stream(input, result_file) do
    if !File.exists?(@results_dir) do
      File.mkdir!(@results_dir)
    end

    pipeline =
      Testing.Pipeline.start_link_supervised!(
        module: TestPipeline,
        custom_args: %{
          input: input,
          result_file: result_file,
          fmt_mapping: @fmt_mapping
        }
      )

    %{video: %{ssrc: video_ssrc}} = input

    assert_start_of_stream(pipeline, {:file_sink, ^video_ssrc})

    assert_end_of_stream(pipeline, {:file_sink, ^video_ssrc}, :input, 4000)

    assert File.read!(@ivf_result_file) == File.read!(@ivf_reference_file)

    Testing.Pipeline.terminate(pipeline, blocking?: true)
  end
end
