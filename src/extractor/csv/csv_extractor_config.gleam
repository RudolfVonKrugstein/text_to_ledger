import extractor/csv/csv_column
import extractor/csv/csv_value
import gleam/dict
import gleam/dynamic/decode
import gleam/list
import gleam/option.{None}
import rule/rule

/// Configuration for a CSV extractor
pub type CsvExtractorConfig {
  CsvExtractorConfig(
    /// The name of the extractor
    name: option.Option(String),
    /// Whether the CSV has headers
    with_headers: Bool,
    /// How the CSV seperates values (a usual choice is ",")
    seperator: String,
    /// Data set on the sheet/global level
    sheet: rule.Rule,
    /// List of values to extract from the CSV file
    /// into variables in the extracted data.
    values: List(csv_value.CsvValue),
  )
}

pub fn decoder() -> decode.Decoder(CsvExtractorConfig) {
  use name <- decode.optional_field(
    "name",
    None,
    decode.optional(decode.string),
  )
  use with_headers <- decode.field("with_headers", decode.bool)
  use seperator <- decode.optional_field("seperator", ",", decode.string)
  use sheet <- decode.field("sheet", rule.decoder())
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
  decode.success(CsvExtractorConfig(
    name:,
    with_headers:,
    seperator:,
    sheet:,
    values:,
  ))
}
