import gleam/dynamic/decode
import gleam/json
import gleam/string

pub type InputFile {
  InputFile(loader: String, name: String, title: String, content: String)
}

pub fn to_json(input_file: InputFile) -> json.Json {
  let InputFile(loader:, name:, title:, content:) = input_file
  json.object([
    #("loader", json.string(loader)),
    #("name", json.string(name)),
    #("title", json.string(title)),
    #("content", json.string(content)),
  ])
}

pub fn decoder() -> decode.Decoder(InputFile) {
  use loader <- decode.field("loader", decode.string)
  use name <- decode.field("name", decode.string)
  use title <- decode.field("title", decode.string)
  use content <- decode.field("content", decode.string)
  decode.success(InputFile(loader:, name:, title:, content:))
}

/// Human readable string
pub fn to_string(i: InputFile) {
  let short_content = case string.length(i.content) {
    l if l <= 512 -> i.content
    l ->
      string.drop_end(i.content, l - 253)
      <> " ... "
      <> string.drop_start(i.content, l - 253)
  }
  "loader: "
  <> i.loader
  <> "\nname: "
  <> i.name
  <> "\ntitle: "
  <> i.title
  <> "\ncontent: "
  <> short_content
}
