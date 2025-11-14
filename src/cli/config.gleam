import dot_env/env
import extractor/enricher
import gleam/dynamic/decode
import gleam/string
import regex/area_regex
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

pub type TemplateConfig {
  TemplateConfig(
    sheet: enricher.Enricher,
    transaction_areas: area_regex.AreaRegex,
  )
}

fn template_config_decoder() -> decode.Decoder(TemplateConfig) {
  use sheet <- decode.field("sheet", enricher.decoder())
  use transaction_areas <- decode.then(
    area_regex.area_regex_optional_field_decoder("transaction_areas"),
  )
  decode.success(TemplateConfig(sheet:, transaction_areas:))
}

/// Config file for cli
pub type Config {
  Config(
    /// Mappings from accound numbers to ledger accounts
    templates: List(TemplateConfig),
    input: InputConfig,
    enrichers: List(enricher.Enricher),
  )
}

pub fn config_decoder() -> decode.Decoder(Config) {
  use templates <- decode.field(
    "templates",
    decode.list(template_config_decoder()),
  )
  use input <- decode.field("input", input_config_decoder())
  use enrichers <- decode.field("enrichers", decode.list(enricher.decoder()))

  decode.success(Config(templates:, input:, enrichers:))
}
