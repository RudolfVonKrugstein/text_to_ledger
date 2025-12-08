import extractor/csv/csv_column.{type CsvColumn}
import gleam/dynamic/decode

/// A value (or variable) taken from CSV.
pub type CsvValue {
  CsvValue(
    /// Name of the variable
    name: String,
    /// The column it is taken from
    column: CsvColumn,
  )
}

pub fn decoder() -> decode.Decoder(CsvValue) {
  use name <- decode.field("name", decode.string)
  use column <- decode.field("column", csv_column.decoder())
  decode.success(CsvValue(name:, column:))
}
