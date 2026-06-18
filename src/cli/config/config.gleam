import cli/config/extractor_config
import cli/config/input_config
import extractor/extractor
import gleam/dynamic/decode
import gleam/list
import rule/rule

/// Config file for cli
pub type Config {
  Config(
    /// Mappings from accound numbers to ledger accounts
    extractors: List(extractor.Extractor),
    inputs: List(input_config.InputConfig),
    rules: List(rule.Rule),
  )
}

pub fn decoder() -> decode.Decoder(Config) {
  use extractors <- decode.field(
    "extractors",
    decode.list(extractor_config.decoder()),
  )
  use inputs <- decode.field("inputs", decode.list(input_config.decoder()))
  use rules <- decode.field(
    "rules",
    decode.list(rule.with_children_decoder()) |> decode.map(list.flatten),
  )

  decode.success(Config(extractors:, inputs:, rules:))
}
