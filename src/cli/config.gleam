import data/bank_statement
import data/matcher
import dot_env/env
import gleam/dict
import gleam/dynamic/decode
import gleam/string
import simplifile

import data/bank_transaction

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
  InputDirectory(directory: String)
  InputPaperless(
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
      use directory <- decode.field("directory", decode.string)
      decode.success(InputDirectory(directory:))
    }
    "paperless" -> {
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
        url:,
        token:,
        allowed_tags:,
        forbidden_tags:,
        document_types:,
      ))
    }
    _ ->
      decode.failure(
        InputDirectory(""),
        "unknown input config type " <> variant,
      )
  }
}

pub type TemplateConfig {
  TemplateConfig(
    statement: bank_statement.BankStatementTemplate,
    transaction: bank_transaction.BankTransactionTemplate,
  )
}

fn template_config_decoder() -> decode.Decoder(TemplateConfig) {
  use statement <- decode.field(
    "statement",
    bank_statement.bank_statement_template_decoder(),
  )
  use transaction <- decode.field(
    "transaction",
    bank_transaction.bank_transaction_template_decoder(),
  )
  decode.success(TemplateConfig(statement:, transaction:))
}

/// Config file for cli
pub type Config {
  Config(
    /// Mappings from accound numbers to ledger accounts
    account_mapping: dict.Dict(String, String),
    templates: List(TemplateConfig),
    input: InputConfig,
    matchers: matcher.Matchers,
  )
}

pub fn config_decoder() -> decode.Decoder(Config) {
  use account_mapping <- decode.field(
    "account_mapping",
    decode.dict(decode.string, decode.string),
  )
  use templates <- decode.field(
    "templates",
    decode.list(template_config_decoder()),
  )
  use input <- decode.field("input", input_config_decoder())
  use matchers <- decode.field(
    "matchers",
    decode.list(matcher.matcher_decoder()),
  )

  decode.success(Config(account_mapping:, templates:, input:, matchers:))
}
