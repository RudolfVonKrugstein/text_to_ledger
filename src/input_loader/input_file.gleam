import gleam/dynamic/decode
import gleam/json
import gleam/option.{type Option, None, Some}
import gleam/string

pub type InputFile {
  InputFile(
    loader: String,
    name: String,
    title: String,
    content: String,
    progress: Int,
    total_files: Option(Int),
  )
}

pub fn to_json(input_file: InputFile) -> json.Json {
  let InputFile(loader:, name:, title:, content:, progress:, total_files:) =
    input_file
  json.object([
    #("loader", json.string(loader)),
    #("name", json.string(name)),
    #("title", json.string(title)),
    #("content", json.string(content)),
    #("progress", json.int(progress)),
    #("total_files", case total_files {
      None -> json.null()
      Some(total_files) -> json.int(total_files)
    }),
  ])
}

pub fn decoder() -> decode.Decoder(InputFile) {
  use loader <- decode.field("loader", decode.string)
  use name <- decode.field("name", decode.string)
  use title <- decode.field("title", decode.string)
  use content <- decode.field("content", decode.string)
  use progress <- decode.field("progress", decode.int)
  use total_files <- decode.optional_field(
    "progress",
    None,
    decode.optional(decode.int),
  )
  decode.success(InputFile(
    loader:,
    name:,
    title:,
    content:,
    progress:,
    total_files:,
  ))
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
