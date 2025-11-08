import data/date
import data/money.{type Money}
import gleam/dynamic/decode
import gleam/option.{type Option, None, Some}
import gleam/regexp
import gleam/result
import regexp_ext/regexp_ext
import template/parser/parser
import template/template

/// A bank statement extracted from the input data.
///
/// All the data for the bank statement is optional.
/// If it is present it is used for sanity checks aand completing the transaction data.
pub type BankStatement {
  BankStatement(
    /// The Bank the statement is from
    bank: Option(String),
    /// The account the statement is for
    account: String,
    /// If this and end_date is present, it is checked if:
    /// * All transactions are inside the time range of there bank statements.
    /// * There is a continous list of bank statements, where the next start_date is the last ones end_date.
    ///
    /// Also when present it can complete the date data of the transactions as `bs_start_date_month` and `bs_start_date_year`.
    start_date: Option(date.Date),
    /// See start_date.
    end_date: Option(date.Date),
    /// The start amount for the bank statement.
    ///
    /// Used for sanity checks and completing the transaction data.
    start_amount: Option(Money),
    /// The end amount for the bank statement.
    ///
    /// Used for sanity checks and completing the transaction data.
    end_amount: Option(Money),
  )
}

pub fn bank_statement_decoder() -> decode.Decoder(BankStatement) {
  use bank <- decode.optional_field(
    "bank",
    None,
    decode.optional(decode.string),
  )
  use account <- decode.field("account", decode.string)
  use start_date <- decode.optional_field(
    "start_date",
    None,
    decode.optional(date.decode_full_date()),
  )
  use end_date <- decode.optional_field(
    "end_date",
    None,
    decode.optional(date.decode_full_date()),
  )
  use start_amount <- decode.optional_field(
    "start_amount",
    None,
    decode.optional(money.decode_money()),
  )
  use end_amount <- decode.optional_field(
    "end_amount",
    None,
    decode.optional(money.decode_money()),
  )
  decode.success(BankStatement(
    bank:,
    account:,
    start_date:,
    end_date:,
    start_amount:,
    end_amount:,
  ))
}

/// Template for extracting bank statement data.
pub type BankStatementTemplate {
  BankStatementTemplate(
    regexes: List(regexp.Regexp),
    bank: Option(template.Template),
    account: template.Template,
    start_date: Option(template.Template),
    end_date: Option(template.Template),
    start_amount: Option(template.Template),
    end_amount: Option(template.Template),
  )
}

pub fn bank_statement_template_decoder() -> decode.Decoder(
  BankStatementTemplate,
) {
  use regexes <- decode.field("regexes", decode.list(regexp_ext.decode_regex()))
  use bank <- decode.optional_field(
    "bank",
    None,
    decode.optional(parser.decode_template()),
  )
  use account <- decode.field("account", parser.decode_template())
  use start_date <- decode.optional_field(
    "start_date",
    None,
    decode.optional(parser.decode_template()),
  )
  use end_date <- decode.optional_field(
    "end_date",
    None,
    decode.optional(parser.decode_template()),
  )
  use start_amount <- decode.optional_field(
    "start_amount",
    None,
    decode.optional(parser.decode_template()),
  )
  use end_amount <- decode.optional_field(
    "end_amount",
    None,
    decode.optional(parser.decode_template()),
  )
  decode.success(BankStatementTemplate(
    regexes:,
    bank:,
    account:,
    start_date:,
    end_date:,
    start_amount:,
    end_amount:,
  ))
}

pub fn parse_template(
  regexes regexes: List(regexp.Regexp),
  bank bank: Option(String),
  account account: String,
  starts_at start_date: Option(String),
  ends_at end_date: Option(String),
  starts_with start_amount: Option(String),
  ends_with end_amount: Option(String),
) {
  use bank <- result.try(case bank {
    None -> Ok(None)
    Some(bank) -> parser.run(bank) |> result.map(Some)
  })
  use account <- result.try(parser.run(account))

  use start_date <- result.try(case start_date {
    None -> Ok(None)
    Some(start_date) -> parser.run(start_date) |> result.map(Some)
  })
  use end_date <- result.try(case end_date {
    None -> Ok(None)
    Some(end_date) -> parser.run(end_date) |> result.map(Some)
  })
  use start_amount <- result.try(case start_amount {
    None -> Ok(None)
    Some(start_amount) -> parser.run(start_amount) |> result.map(Some)
  })
  use end_amount <- result.try(case end_amount {
    None -> Ok(None)
    Some(end_amount) -> parser.run(end_amount) |> result.map(Some)
  })

  Ok(BankStatementTemplate(
    regexes:,
    bank:,
    account:,
    start_date:,
    end_date:,
    start_amount:,
    end_amount:,
  ))
}
