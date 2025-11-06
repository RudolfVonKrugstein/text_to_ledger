import data/money.{type Money}
import gleam/option.{type Option, None, Some}
import gleam/regexp.{type Regexp}
import gleam/result
import gleam/time/calendar
import template/parser/parser
import template/template

/// A Bank Transaction extracted from the input dataz.
pub type BankTransaction {
  BankTransaction(
    subject: String,
    amount: Money,
    booking_date: Option(calendar.Date),
    execution_date: calendar.Date,
  )
}

/// Template for extracting bank transactions data.
pub type BankTransactionTemplate {
  BankTransactionTemplate(
    regexes: List(Regexp),
    start_regex: StartRegex,
    end_regex: EndRegex,
    subject: template.Template,
    amount: template.Template,
    book_date: Option(template.Template),
    exec_date: template.Template,
  )
}

pub type StartRegex {
  BeginWith(regexp.Regexp)
  BeginAfter(regexp.Regexp)
}

pub type EndRegex {
  EndBefore(regexp.Regexp)
  EndWith(regexp.Regexp)
}

pub fn parse_template(
  regexes regexes: List(Regexp),
  start start_regex: StartRegex,
  end end_regex: EndRegex,
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
