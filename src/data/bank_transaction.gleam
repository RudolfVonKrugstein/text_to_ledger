import data/date
import data/money.{type Money}
import gleam/dynamic/decode
import gleam/option.{type Option, None, Some}
import gleam/result
import input_loader/input_file.{type InputFile}
import regex/area_regex
import regex/regex
import template/parser/parser
import template/template

/// A Bank Transaction extracted from the input dataz.
pub type BankTransaction {
  BankTransaction(
    /// The document this comes from
    origin: InputFile,
    subject: String,
    amount: Money,
    booking_date: date.Date,
    execution_date: Option(date.Date),
  )
}

pub fn bank_transaction_decoder() -> decode.Decoder(BankTransaction) {
  use origin <- decode.field("origin", input_file.input_file_decoder())
  use subject <- decode.field("subject", decode.string)
  use amount <- decode.field("amount", money.decode_money())
  use booking_date <- decode.field("booking_date", date.decode_full_date())
  use execution_date <- decode.field(
    "execution_date",
    decode.optional(date.decode_full_date()),
  )
  decode.success(BankTransaction(
    origin:,
    subject:,
    amount:,
    booking_date:,
    execution_date:,
  ))
}

/// Template for extracting bank transactions data.
pub type BankTransactionTemplate {
  BankTransactionTemplate(
    regexes: List(regex.RegexWithOpts),
    area: area_regex.AreaRegex,
    subject: template.Template,
    amount: template.Template,
    book_date: template.Template,
    exec_date: Option(template.Template),
  )
}

pub fn bank_transaction_template_decoder() -> decode.Decoder(
  BankTransactionTemplate,
) {
  use regexes <- decode.field("regexes", decode.list(regex.regex_opt_decoder()))
  use area <- decode.then(area_regex.area_regex_optional_field_decoder("area"))
  use subject <- decode.field("subject", parser.decode_template())
  use amount <- decode.field("amount", parser.decode_template())
  use book_date <- decode.field("booking_date", parser.decode_template())
  use exec_date <- decode.optional_field(
    "execution_date",
    None,
    decode.optional(parser.decode_template()),
  )
  decode.success(BankTransactionTemplate(
    regexes:,
    area:,
    subject:,
    amount:,
    book_date:,
    exec_date:,
  ))
}

pub fn parse_template(
  regexes regexes: List(regex.RegexWithOpts),
  area area: area_regex.AreaRegex,
  subject subject: String,
  amount amount: String,
  booking_date booking_date: String,
  execution_date execution_date: Option(String),
) {
  use subject <- result.try(parser.run(subject))
  use amount <- result.try(parser.run(amount))
  use book_date <- result.try(parser.run(booking_date))
  use exec_date <- result.try(case execution_date {
    None -> Ok(None)
    Some(execution_date) -> parser.run(execution_date) |> result.map(Some)
  })

  Ok(BankTransactionTemplate(
    regexes:,
    area:,
    subject:,
    amount:,
    book_date:,
    exec_date:,
  ))
}
