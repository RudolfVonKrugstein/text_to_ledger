import cli/config/extractor_config
import cli/config/input_config
import enricher/enricher
import extractor/extractor
import gleam/dynamic/decode

/// Config file for cli
pub type Config {
  Config(
    /// Mappings from accound numbers to ledger accounts
    extractors: List(extractor.Extractor),
    input: input_config.InputConfig,
    enrichers: List(enricher.Enricher),
  )
}

pub fn decoder() -> decode.Decoder(Config) {
  use extractors <- decode.field(
    "extractors",
    decode.list(extractor_config.decoder()),
  )
  use input <- decode.field("input", input_config.decoder())
  use enrichers <- decode.field("enrichers", decode.list(enricher.decoder()))

  decode.success(Config(extractors:, input:, enrichers:))
}
