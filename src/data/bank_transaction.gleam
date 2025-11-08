import data/date
import data/money.{type Money}
import gleam/option.{type Option, None, Some}
import gleam/regexp.{type Regexp}
import gleam/result
import regexp_ext/regexp_ext
import template/parser/parser
import template/template

/// A Bank Transaction extracted from the input dataz.
pub type BankTransaction {
  BankTransaction(
    subject: String,
    amount: Money,
    booking_date: Option(date.Date),
    execution_date: date.Date,
  )
}

/// Template for extracting bank transactions data.
pub type BankTransactionTemplate {
  BankTransactionTemplate(
    regexes: List(Regexp),
    start_regex: regexp_ext.SplitRegex,
    end_regex: regexp_ext.SplitRegex,
    subject: template.Template,
    amount: template.Template,
    book_date: Option(template.Template),
    exec_date: template.Template,
  )
}

pub fn parse_template(
  regexes regexes: List(Regexp),
  start start_regex: regexp_ext.SplitRegex,
  end end_regex: regexp_ext.SplitRegex,
  subject subject: String,
  amount amount: String,
  booking_date booking_date: Option(String),
  execution_date execution_date: String,
) {
  use subject <- result.try(parser.run(subject))
  use amount <- result.try(parser.run(amount))
  use book_date <- result.try(case booking_date {
    None -> Ok(None)
    Some(booking_date) -> parser.run(booking_date) |> result.map(Some)
  })
  use exec_date <- result.try(parser.run(execution_date))

  Ok(BankTransactionTemplate(
    regexes:,
    start_regex:,
    end_regex:,
    subject:,
    amount:,
    book_date:,
    exec_date:,
  ))
}
