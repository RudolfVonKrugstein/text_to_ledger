import gleam/dynamic/decode
import gleam/string

pub type InputFile {
  InputFile(name: String, title: String, content: String)
}

pub fn input_file_decoder() -> decode.Decoder(InputFile) {
  use name <- decode.field("name", decode.string)
  use title <- decode.field("title", decode.string)
  use content <- decode.field("content", decode.string)
  decode.success(InputFile(name:, title:, content:))
}

/// Human readable string
pub fn to_string(i: InputFile) {
  let short_content = case string.length(i.content) {
    l if l <= 256 -> i.content
    l ->
      string.drop_end(i.content, l - 120)
      <> " ... "
      <> string.drop_start(i.content, l - 120)
  }
  "name: " <> i.name <> "\ntitle: " <> i.title <> "\ncontent: " <> short_content
}
