defmodule Membrane.RTP.VP8.CaptureBuffer do
  use ExUnit.Case
  import Membrane.Testing.Assertions

  alias Membrane.Testing
  alias Membrane.BufferCapture.CaptureMaker
  alias Membrane.Element.IVF

  defmodule TestPipeline do
    use Membrane.Pipeline

    @impl true
    def handle_init(options) do
      spec = %ParentSpec{
        children: [
          file_source: %Membrane.File.Source{
            location:
              "/Users/andrzej/Membrane/membrane_rtp_vp8_plugin/test/fixtures/input_vp8.ivf"
          },
          deserializer: IVF.Deserializer,
          capture_maker: %CaptureMaker{
            location: "/Users/andrzej/Membrane/membrane_rtp_vp8_plugin/test/results/input_vp8.dump"
          }
        ],
        links: [
          link(:file_source)
          |> to(:deserializer)
          |> to(:capture_maker)
        ]
      }

      {{:ok, spec: spec}, %{}}
    end

    @impl true
    def handle_notification(_notification, _child, _ctx, state) do
      {:ok, state}
    end
  end

  test "make capture" do
    {:ok, pipeline} =
      %Testing.Pipeline.Options{module: TestPipeline} |> Testing.Pipeline.start_link()

    Testing.Pipeline.play(pipeline)

    assert_pipeline_playback_changed(pipeline, _, :playing)

    assert_end_of_stream(pipeline, :capture_maker)

    Testing.Pipeline.stop(pipeline)
    assert_pipeline_playback_changed(pipeline, _, :stopped)
  end
end
