defmodule Membrane.RTP.VP8.RTPIntegrationTest do
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

  @fmt_mapping %{96 => %{encoding_name: :VP8, clock_rate: 90_000}}

  test "depayloading rtp with vp8", %{tmp_dir: tmp_dir} do
    defmodule TestPipeline do
      use Membrane.Pipeline

      @impl true
      def handle_init(_ctx, options) do
        spec =
          child(:pcap, %Membrane.Pcap.Source{path: options.input.pcap})
          |> child(:rtp_demuxer, %Membrane.RTP.Demuxer{payload_type_mapping: options.fmt_mapping})
          |> via_out(:output, options: [stream_id: {:encoding_name, :VP8}])
          |> child(:depayloader, Membrane.RTP.VP8.Depayloader)
          |> child(:ivf_writer, %IVF.Serializer{
            width: options.input.video.width,
            height: options.input.video.height,
            scale: 1,
            rate: 30
          })
          |> child(:file_sink, %Membrane.File.Sink{location: options.result_file})

        {[spec: spec], %{}}
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

    assert_start_of_stream(pipeline, :file_sink)
    assert_end_of_stream(pipeline, :file_sink, :input, 4000)

    assert File.read!(result_file) == File.read!(@ivf_reference_file)

    Testing.Pipeline.terminate(pipeline)
  end

  test "payloading and depayloading back", %{tmp_dir: tmp_dir} do
    result_file = Path.join(tmp_dir, @ivf_result_file)

    pipeline =
      Testing.Pipeline.start_link_supervised!(
        spec:
          child(:source, %Membrane.File.Source{location: @ivf_reference_file})
          |> child(:deserializer, IVF.Deserializer)
          |> child(:payloader, RTP.VP8.Payloader)
          |> child(:rtp_muxer, %Membrane.RTP.Muxer{payload_type_mapping: @fmt_mapping})
          |> child(:rtp_demuxer, %Membrane.RTP.Demuxer{payload_type_mapping: @fmt_mapping})
          |> via_out(:output, options: [stream_id: {:encoding_name, :VP8}])
          |> child(:depayloader, Membrane.RTP.VP8.Depayloader)
          |> child(:ivf_writer, %IVF.Serializer{
            width: @rtp_input.video.width,
            height: @rtp_input.video.height,
            scale: 1,
            rate: 30
          })
          |> child(:sink, %Membrane.File.Sink{location: result_file})
      )

    assert_end_of_stream(pipeline, :sink, :input, 4000)

    assert File.read!(result_file) == File.read!(@ivf_reference_file)
    Testing.Pipeline.terminate(pipeline)
  end
end
