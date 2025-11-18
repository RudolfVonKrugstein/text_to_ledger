import extractor/csv/csv_column.{type CsvColumn}
import gleam/dynamic/decode

pub type CsvValue {
  CsvValue(name: String, column: CsvColumn)
}

pub fn decoder() -> decode.Decoder(CsvValue) {
  use name <- decode.field("name", decode.string)
  use column <- decode.field("column", csv_column.decoder())
  decode.success(CsvValue(name:, column:))
}
