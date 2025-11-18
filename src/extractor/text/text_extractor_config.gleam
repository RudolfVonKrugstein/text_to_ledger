import enricher/enricher
import gleam/dynamic/decode
import regex/area_regex

pub type TextExtractorConfig {
  TextExtractorConfig(
    sheet: enricher.Enricher,
    transaction_areas: area_regex.AreaRegex,
  )
}

pub fn decoder() -> decode.Decoder(TextExtractorConfig) {
  use sheet <- decode.field("sheet", enricher.decoder())
  use transaction_areas <- decode.field(
    "transaction_areas",
    area_regex.decoder(),
  )
  decode.success(TextExtractorConfig(sheet:, transaction_areas:))
}
