import cli/config/extractor_config
import cli/config/input_config
import cli/suggester.{type Suggester}
import extractor/extractor
import gleam/dynamic/decode
import gleam/list
import gleam/option.{type Option, None}
import rule/rule

/// Config file for cli
pub type Config {
  Config(
    /// Mappings from accound numbers to ledger accounts
    extractors: List(extractor.Extractor),
    inputs: List(input_config.InputConfig),
    rules: List(rule.Rule),
    /// Optional external suggester used by the `test-rules` command to
    /// pre-fill the editor with a generated rule.
    suggester: Option(Suggester),
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
  use suggester <- decode.optional_field(
    "suggester",
    None,
    decode.optional(suggester.decoder()),
  )
  
  decode.success(Config(extractors:, inputs:, rules:, suggester:))
}
