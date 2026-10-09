# Membrane RTP VP8 plugin

[![Star Membrane on GitHub ★](https://img.shields.io/github/stars/membraneframework/membrane_core?style=flat&logo=github&label=Star%20Membrane%20on%20GitHub%20%E2%98%85&color=blue)](https://github.com/membraneframework/membrane_core)
[![Hex.pm](https://img.shields.io/hexpm/v/membrane_rtp_vp8_plugin.svg)](https://hex.pm/packages/membrane_rtp_vp8_plugin)
[![API Docs](https://img.shields.io/badge/api-docs-yellow.svg?style=flat)](https://hexdocs.pm/membrane_rtp_vp8_plugin/)
[![CI](https://github.com/membraneframework/membrane_rtp_vp8_plugin/actions/workflows/ci.yml/badge.svg)](https://github.com/membraneframework/membrane_rtp_vp8_plugin/actions/workflows/ci.yml)

RTP payloader and depayloader for VP8.

It is part of [Membrane Multimedia Framework](https://membrane.stream).

## Installation

The package can be installed by adding `membrane_rtp_vp8_plugin` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
	  {:membrane_rtp_vp8_plugin, "~> 0.9.7"}
  ]
end
```

## Usage

This plugin registers the default payloader and depayloader for VP8 [RTP payload format](https://hexdocs.pm/membrane_rtp_format/Membrane.RTP.PayloadFormat.html)
and thus can be automatically used by [Membrane RTP plugin](https://hexdocs.pm/membrane_rtp_plugin) whenever added to dependencies.
Of course, it can be manually linked in a custom pipeline too.

## Copyright and License

Copyright 2020, [Software Mansion](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane_rtp_vp8_plugin)

[![Software Mansion](https://logo.swmansion.com/logo?color=white&variant=desktop&width=200&tag=membrane-github)](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane_rtp_vp8_plugin)

Licensed under the [Apache License, Version 2.0](LICENSE)
