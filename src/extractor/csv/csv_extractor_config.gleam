import enricher/enricher
import extractor/csv/csv_column
import extractor/csv/csv_value
import gleam/dict
import gleam/dynamic/decode
import gleam/list

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
  use values <- decode.field(
    "values",
    decode.dict(decode.string, csv_column.decoder()),
  )
  let values =
    values
    |> dict.to_list
    |> list.map(fn(v) {
      let #(name, column) = v
      csv_value.CsvValue(name, column)
    })
  decode.success(CsvExtractorConfig(with_headers:, seperator:, sheet:, values:))
}
