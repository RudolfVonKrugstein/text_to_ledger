import dot_env/env
import extractor/csv_extractor
import extractor/enricher
import extractor/extractor
import extractor/text_extractor
import gleam/dynamic/decode
import gleam/string
import simplifile

/// A String, that can also be loaded from an external source
pub fn external_string_decoder() {
  decode.one_of(decode.string, [
    {
      use var <- decode.field("env_var", decode.string)
      case env.get_string(var) {
        Ok(s) -> decode.success(s)
        Error(e) ->
          decode.failure("", "unable to load env var " <> var <> ": " <> e)
      }
    },
    {
      use file <- decode.field("file", decode.string)
      case simplifile.read(file) {
        Ok(s) -> decode.success(s)
        Error(e) ->
          decode.failure(
            "",
            "unable to load " <> file <> ": " <> string.inspect(e),
          )
      }
    },
  ])
}

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

fn input_config_decoder() -> decode.Decoder(InputConfig) {
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
      use token <- decode.field("token", external_string_decoder())
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

pub fn extractor_decoder() -> decode.Decoder(extractor.Extractor) {
  use variant <- decode.field("type", decode.string)
  case variant {
    "text" -> {
      use config <- decode.then(text_extractor.config_decoder())
      decode.success(text_extractor.new(config))
    }
    "csv" -> {
      use config <- decode.then(csv_extractor.config_decoder())
      decode.success(csv_extractor.new(config))
    }
    _ ->
      decode.failure(
        extractor.Extractor(fn(_) { Error("invalid") }),
        "extractor type '" <> variant <> "' is not known",
      )
  }
}

/// Config file for cli
pub type Config {
  Config(
    /// Mappings from accound numbers to ledger accounts
    extractors: List(extractor.Extractor),
    input: InputConfig,
    enrichers: List(enricher.Enricher),
  )
}

pub fn config_decoder() -> decode.Decoder(Config) {
  use extractors <- decode.field("extractors", decode.list(extractor_decoder()))
  use input <- decode.field("input", input_config_decoder())
  use enrichers <- decode.field("enrichers", decode.list(enricher.decoder()))

  decode.success(Config(extractors:, input:, enrichers:))
}
