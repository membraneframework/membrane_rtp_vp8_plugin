defmodule Membrane.RTP.VP8.Plugin.App do
  @moduledoc false
  use Application
  alias Membrane.RTP.{VP8, PayloadFormat}

  @impl true
  def start(_type, _args) do
    PayloadFormat.register(%PayloadFormat{
      encoding_name: :VP8,
      payload_type: 97,
      depayloader: VP8.Depayloader,
      payloader: VP8.Payloader
    })

    PayloadFormat.register_payload_type_mapping(97, :VP8, 90_000)
    Supervisor.start_link([], strategy: :one_for_one, name: __MODULE__)
  end
end
