import enricher/enricher
import extractor/csv/csv_value
import gleam/dynamic/decode

pub type CsvExtractorConfig {
  CsvExtractorConfig(
    with_headers: Bool,
    seperator: String,
    sheet: enricher.Enricher,
    values: List(csv_value.CsvValue),
  )
}

pub fn decoder() -> decode.Decoder(CsvExtractorConfig) {
  use with_headers <- decode.field("with_headers", decode.bool)
  use seperator <- decode.optional_field("seperator", ",", decode.string)
  use sheet <- decode.field("sheet", enricher.decoder())
  use values <- decode.field("values", decode.list(csv_value.decoder()))
  decode.success(CsvExtractorConfig(with_headers:, seperator:, sheet:, values:))
}
