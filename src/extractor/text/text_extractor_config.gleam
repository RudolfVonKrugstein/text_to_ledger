import enricher/enricher
import gleam/dynamic/decode
import gleam/option.{type Option, None}
import regex/area_regex

/// Configuration for a text extractor.
pub type TextExtractorConfig {
  TextExtractorConfig(
    /// The name
    name: Option(String),
    /// Global/sheet data
    sheet: enricher.Enricher,
    /// The areas where each contains a transaction
    transaction_areas: area_regex.AreaRegex,
  )
}

pub fn decoder() -> decode.Decoder(TextExtractorConfig) {
  use name <- decode.optional_field(
    "name",
    None,
    decode.optional(decode.string),
  )
  use sheet <- decode.field("sheet", enricher.decoder())
  use transaction_areas <- decode.field(
    "transaction_areas",
    area_regex.decoder(),
  )
  decode.success(TextExtractorConfig(name:, sheet:, transaction_areas:))
}
