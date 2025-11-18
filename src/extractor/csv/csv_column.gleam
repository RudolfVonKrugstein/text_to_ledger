import gleam/dynamic/decode

pub type CsvColumn {
  ByIndex(index: Int)
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
