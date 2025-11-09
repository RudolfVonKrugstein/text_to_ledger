import data/date
import data/money.{type Money}
import data/regex
import data/split_regex
import gleam/dynamic/decode
import gleam/option.{type Option, None, Some}
import gleam/result
import template/parser/parser
import template/template

/// A Bank Transaction extracted from the input dataz.
pub type BankTransaction {
  BankTransaction(
    subject: String,
    amount: Money,
    booking_date: date.Date,
    execution_date: Option(date.Date),
  )
}

pub fn bank_transaction_decoder() -> decode.Decoder(BankTransaction) {
  use subject <- decode.field("subject", decode.string)
  use amount <- decode.field("amount", money.decode_money())
  use booking_date <- decode.field("booking_date", date.decode_full_date())
  use execution_date <- decode.field(
    "execution_date",
    decode.optional(date.decode_full_date()),
  )
  decode.success(BankTransaction(
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
    start_area_regex: Option(split_regex.SplitRegex),
    end_area_regex: Option(split_regex.SplitRegex),
    start_regex: split_regex.SplitRegex,
    end_regex: split_regex.SplitRegex,
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
  use start_area_regex <- decode.optional_field(
    "start_area_regex",
    None,
    decode.optional(split_regex.split_regex_decoder()),
  )
  use end_area_regex <- decode.optional_field(
    "end_area_regex",
    None,
    decode.optional(split_regex.split_regex_decoder()),
  )
  use start_regex <- decode.field(
    "start_regex",
    split_regex.split_regex_decoder(),
  )
  use end_regex <- decode.field("end_regex", split_regex.split_regex_decoder())
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
    start_area_regex:,
    end_area_regex:,
    start_regex:,
    end_regex:,
    subject:,
    amount:,
    book_date:,
    exec_date:,
  ))
}

pub fn parse_template(
  regexes regexes: List(regex.RegexWithOpts),
  start_area start_area_regex: Option(split_regex.SplitRegex),
  end_area end_area_regex: Option(split_regex.SplitRegex),
  start start_regex: split_regex.SplitRegex,
  end end_regex: split_regex.SplitRegex,
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
    start_area_regex:,
    end_area_regex:,
    start_regex:,
    end_regex:,
    subject:,
    amount:,
    book_date:,
    exec_date:,
  ))
}
