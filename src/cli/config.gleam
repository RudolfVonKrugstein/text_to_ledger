import data/bank_statement
import gleam/dict
import gleam/dynamic/decode

import data/bank_transaction

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
  /// Mappings from accound numbers to ledger accounts
  Config(
    account_mapping: dict.Dict(String, String),
    templates: List(TemplateConfig),
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
  decode.success(Config(account_mapping:, templates:))
}
