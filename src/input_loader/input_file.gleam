import gleam/dynamic/decode

pub type InputFile {
  InputFile(name: String, title: String, content: String)
}

pub fn input_file_decoder() -> decode.Decoder(InputFile) {
  use name <- decode.field("name", decode.string)
  use title <- decode.field("title", decode.string)
  use content <- decode.field("content", decode.string)
  decode.success(InputFile(name:, title:, content:))
}
