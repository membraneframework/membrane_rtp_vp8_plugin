defmodule Membrane.Template.Mixfile do
  use Mix.Project

  @version "0.1.0"
  @github_url "https://github.com/membraneframework/membrane_rtp_vp8_plugin"

  def project do
    [
      app: :membrane_rtp_vp8_plugin,
      version: @version,
      elixir: "~> 1.10",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # hex
      description: "Membrane Multimedia Framework (RTP VP8)",
      package: package(),

      # docs
      name: "Membrane: RTP VP8",
      source_url: @github_url,
      homepage_url: "https://membraneframework.org",
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [],
      mod: {Membrane.RTP.VP8.Plugin.App, []}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_env), do: ["lib"]

  defp deps do
    [
      {:membrane_core,
       github: "membraneframework/membrane_core", branch: "remote_stream", override: true},
      {:ex_doc, "~> 0.22", only: :dev, runtime: false},
      {:dialyxir, "~> 1.0.0", only: :dev, runtime: false},
      {:credo, "~> 1.4", only: :dev, runtime: false},
      {:membrane_rtp_format, "~> 0.3.1"},
      {:membrane_remote_stream_format, "~> 0.1.0"},
      {:membrane_vp8_format, github: "membraneframework/membrane_vp8_format", branch: "master"},
      {:membrane_element_pcap, github: "membraneframework/membrane-element-pcap", only: :test},
      {:membrane_file_plugin, "~> 0.5.0", only: :test},
      {:membrane_rtp_plugin, "~> 0.5.0", only: :test},
      {:ex_libsrtp, "~> 0.1.0"},
      {:membrane_ivf_plugin,
       github: "membraneframework/membrane_ivf_plugin",
       branch: "deserializer",
       only: :test},
       {:membrane_buffer_capture_plugin, github: "membraneframework/membrane_buffer_capture_plugin", branch: "capture-maker" ,only: :test}
    ]
  end

  defp package do
    [
      maintainers: ["Membrane Team"],
      licenses: ["Apache 2.0"],
      links: %{
        "GitHub" => @github_url,
        "Membrane Framework Homepage" => "https://membraneframework.org"
      }
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "LICENSE"],
      source_ref: "v#{@version}",
      nest_modules_by_prefix: [Membrane.RTP.VP8]
    ]
  end
end
