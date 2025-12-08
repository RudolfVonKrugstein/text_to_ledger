import gleam/dynamic/decode

/// Specifying a column in CSV for extracting
pub type CsvColumn {
  /// The index of the column
  ByIndex(index: Int)
  /// The name (or title) of the column
  ByName(name: String)
}

pub fn decoder() -> decode.Decoder(CsvColumn) {
  decode.one_of(
    decode.field("index", decode.int, fn(i) { decode.success(ByIndex(i)) }),
    [
      decode.string |> decode.map(fn(n) { ByName(n) }),
      decode.field("name", decode.string, fn(n) { decode.success(ByName(n)) }),
    ],
  )
}
