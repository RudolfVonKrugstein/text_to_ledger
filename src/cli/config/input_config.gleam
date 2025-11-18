import cli/config/external_string
import gleam/dynamic/decode
import input_loader/directory_loader
import input_loader/error
import input_loader/input_loader
import input_loader/paperless_loader

pub type InputConfig {
  InputDirectory(name: String, directory: String)
  InputPaperless(
    name: String,
    url: String,
    token: String,
    allowed_tags: List(String),
    forbidden_tags: List(String),
    document_types: List(String),
  )
}

pub fn name(c: InputConfig) {
  case c {
    InputDirectory(_, _) -> "directory"
    InputPaperless(_, _, _, _, _, _) -> "paperless"
  }
}

pub fn decoder() -> decode.Decoder(InputConfig) {
  use variant <- decode.field("type", decode.string)
  case variant {
    "directory" -> {
      use name <- decode.field("name", decode.string)
      use directory <- decode.field("directory", decode.string)
      decode.success(InputDirectory(name:, directory:))
    }
    "paperless" -> {
      use name <- decode.field("name", decode.string)
      use url <- decode.field("url", decode.string)
      use token <- decode.field("token", external_string.decoder())
      use allowed_tags <- decode.optional_field(
        "allowed_tags",
        [],
        decode.list(decode.string),
      )
      use forbidden_tags <- decode.optional_field(
        "forbidden_tags",
        [],
        decode.list(decode.string),
      )
      use document_types <- decode.field(
        "document_types",
        decode.list(decode.string),
      )
      decode.success(InputPaperless(
        name:,
        url:,
        token:,
        allowed_tags:,
        forbidden_tags:,
        document_types:,
      ))
    }
    _ ->
      decode.failure(
        InputDirectory("", ""),
        "unknown input config type " <> variant,
      )
  }
}

pub fn create_input_loader(
  config: InputConfig,
) -> Result(input_loader.InputLoader, error.InputLoaderError) {
  case config {
    InputDirectory(name:, directory:) -> directory_loader.new(name, directory)
    InputPaperless(
      name:,
      url:,
      token:,
      allowed_tags:,
      forbidden_tags:,
      document_types:,
    ) ->
      paperless_loader.new(
        name,
        url,
        token,
        allowed_tags,
        forbidden_tags,
        document_types,
      )
  }
}
