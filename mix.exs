defmodule Membrane.RTP.VP8.Plugin.Mixfile do
  use Mix.Project

  @version "0.9.6"
  @github_url "https://github.com/membraneframework/membrane_rtp_vp8_plugin"

  def project do
    [
      app: :membrane_rtp_vp8_plugin,
      version: @version,
      elixir: "~> 1.12",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: dialyzer(),

      # hex
      description: "Membrane RTP payloader and depayloader for VP8",
      package: package(),

      # docs
      name: "Membrane RTP VP8 Plugin",
      source_url: @github_url,
      homepage_url: "https://membrane.stream",
      docs: docs(),
      aliases: [docs: ["docs", &prepend_llms_links/1]]
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
      {:membrane_core, "~> 1.0"},
      {:membrane_vp8_format, "~> 0.5.0 or ~> 0.4.0"},
      {:membrane_rtp_format, "~> 0.11.0"},
      {:ex_doc, "~> 0.40", only: :dev, runtime: false},
      {:dialyxir, ">= 0.0.0", only: :dev, runtime: false},
      {:credo, ">= 0.0.0", only: :dev, runtime: false},

      # Test deps
      {:membrane_file_plugin, "~> 0.16.0", only: :test},
      {:membrane_rtp_plugin, "~> 0.31.0", only: :test},
      {:ex_libsrtp, ">= 0.0.0", only: :test},
      {:membrane_pcap_plugin,
       github: "membraneframework-labs/membrane_pcap_plugin", tag: "v0.9.0", only: :test},
      {:membrane_ivf_plugin, "~> 0.7.0", only: :test}
    ]
  end

  defp dialyzer() do
    opts = [
      flags: [:error_handling]
    ]

    if System.get_env("CI") == "true" do
      # Store PLTs in cacheable directory for CI
      [plt_local_path: "priv/plts", plt_core_path: "priv/plts"] ++ opts
    else
      opts
    end
  end

  defp package do
    [
      maintainers: ["Membrane Team"],
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => @github_url,
        "Membrane Framework Homepage" => "https://membrane.stream"
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

  defp prepend_llms_links(_) do
    output_dir = docs()[:output] || "doc"
    path = Path.join(output_dir, "llms.txt")

    if File.exists?(path) do
      existing = File.read!(path)

      footer = """


      ## See Also

      - [Membrane Framework AI Skill](https://hexdocs.pm/membrane_core/skill.md)
      - [Membrane Core](https://hexdocs.pm/membrane_core/llms.txt)
      """

      File.write!(path, String.trim_trailing(existing) <> footer)
    else
      IO.warn("#{path} not found — llms.txt was not generated, check your ex_doc configuration")
    end
  end
end
