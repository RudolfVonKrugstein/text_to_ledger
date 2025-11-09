import data/bank_statement
import data/bank_transaction
import data/date
import data/money
import data/regex
import data/split_regex
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import regexp_ext/regexp_ext
import template/template

/// Collect variables by applying regexes and getting all values for named captures groups.
fn collect_variables(regexes: List(regex.RegexWithOpts), doc: String) {
  extend_variables(regexes, doc, template.empty_vars())
}

/// Extend variables by applying regexes and getting all values for named captures groups.
fn extend_variables(
  regexes: List(regex.RegexWithOpts),
  doc: String,
  start: template.Vars,
) {
  list.fold(regexes, start, fn(vars, regex) {
    let captures = regexp_ext.capture_names(with: regex.regex, over: doc)

    list.fold(list.flatten(captures), vars, fn(vars, capture) {
      let regexp_ext.NamedCapture(name:, value:) = capture

      template.add_to_vars(vars, name, value)
    })
  })
}

// Helper function, like option.map but with a function that returns
// a result. The `Option` and `Result` container are than swapped.
pub fn option_map_result(
  opt: Option(a),
  trans: fn(a) -> Result(b, String),
) -> Result(Option(b), String) {
  case opt {
    None -> Ok(None)
    Some(val) -> trans(val) |> result.map(Some)
  }
}

// Render a template, that is only wrapped in an option.
pub fn option_render_template(
  temp: Option(template.Template),
  vars: template.Vars,
) {
  option_map_result(temp, template.render(_, vars))
}

// Split the transactions texts from the original input.
fn split_transactions(
  input: String,
  trans_template: bank_transaction.BankTransactionTemplate,
) {
  // Find the beginning of the next transactin
  split_regex.split_all(trans_template.start_regex, input)
  |> list.drop(1)
  |> list.map(fn(begining) {
    case split_regex.split(trans_template.end_regex, begining) {
      None -> begining
      Some(#(begining, _)) -> begining
    }
  })
}

// Helper function, rendering a variable and parsing it as money.
fn extract_money(temp: template.Template, vars: template.Vars) {
  use amount <- result.try(template.render(temp, vars))

  money.parse_money(amount, Some("."), None)
}

// Helper function, rendering a variable and  parsing a partial date
// that may be missing the year from it.
fn extract_trans_date(
  temp: template.Template,
  vars: template.Vars,
  min_date: Option(date.Date),
  max_date: Option(date.Date),
) -> Result(date.Date, String) {
  use date <- result.try(template.render(temp, vars))

  use date <- result.try(date.parse_partial_date_with_day(
    date,
    ".",
    date.DayMonthYear,
  ))

  use date <- result.try(date.full_date_from_range(date, min_date, max_date))

  Ok(date)
}

// Helper function, rendering a variable and  parsing a partial date
// that may be missing the day and month from it.
// This dates occure in the date range of a bank statement.
fn extract_range_date(
  temp: template.Template,
  vars: template.Vars,
  start: Bool,
) -> Result(date.Date, String) {
  use date <- result.try(template.render(temp, vars))

  use date <- result.try(date.parse_partial_date_with_year(
    date,
    ".",
    date.DayMonthYear,
  ))

  case start {
    True -> Ok(date.first_possible_date(date))
    False -> Ok(date.last_possible_date(date))
  }
}

/// Extract all date about a transaction from the input text.
///
/// # Arguments:
/// - `input`: the transaction test to extract the data from.
/// - `trans_template`: Information on how to extract the data.
/// - `bank_vars`: Variables collected from the bank statement.
/// - `min_date`: Optional, the starting date of the bank statement.
///               If given is used to complete and verify the dates of the
///               transactions.
/// - `max_date`: Optional, the last date of the bank statement.
///               If given is used to complete and verify the dates of the
///               transactions.
fn extract_transaction_data(
  input: String,
  trans_template: bank_transaction.BankTransactionTemplate,
  bank_vars: template.Vars,
  min_date: Option(date.Date),
  max_date: Option(date.Date),
) {
  // collect transaction variables
  let trans_vars = extend_variables(trans_template.regexes, input, bank_vars)

  use subject <- result.try(template.render(trans_template.subject, trans_vars))
  use amount <- result.try(extract_money(trans_template.amount, trans_vars))
  use execution_date <- result.try(
    option_map_result(trans_template.exec_date, extract_trans_date(
      _,
      trans_vars,
      min_date,
      max_date,
    )),
  )
  use booking_date <- result.try(extract_trans_date(
    trans_template.book_date,
    trans_vars,
    min_date,
    max_date,
  ))

  // The result
  Ok(bank_transaction.BankTransaction(
    subject:,
    amount:,
    booking_date:,
    execution_date:,
  ))
}

/// Extract all date about a bank statement (including transactions) from the input text.
///
/// # Arguments:
/// - `input`: the transaction test to extract the data from.
/// - `bs_template`: Information on how to extract the data for the bank statement.
/// - `trans_template`: Information on how to extract the data for the transcactions.
pub fn extract_bank_statement_data(
  input: String,
  bs_template: bank_statement.BankStatementTemplate,
  trans_template: bank_transaction.BankTransactionTemplate,
) {
  // collect bank variables
  let bank_vars = collect_variables(bs_template.regexes, input)

  use bank <- result.try(option_render_template(bs_template.bank, bank_vars))
  use account <- result.try(template.render(bs_template.account, bank_vars))

  use start_date <- result.try(
    option_map_result(bs_template.start_date, extract_range_date(
      _,
      bank_vars,
      True,
    )),
  )
  use end_date <- result.try(
    option_map_result(bs_template.end_date, extract_range_date(
      _,
      bank_vars,
      False,
    )),
  )

  use start_amount <- result.try(
    option_map_result(bs_template.start_amount, extract_money(_, bank_vars)),
  )
  use end_amount <- result.try(
    option_map_result(bs_template.end_amount, extract_money(_, bank_vars)),
  )

  // fill the bank data
  let statement =
    bank_statement.BankStatement(
      bank:,
      account:,
      start_date:,
      end_date:,
      start_amount:,
      end_amount:,
    )

  let transaction_texts = split_transactions(input, trans_template)

  use transactions <- result.try(
    result.all(
      list.map(transaction_texts, extract_transaction_data(
        _,
        trans_template,
        bank_vars,
        start_date,
        end_date,
      )),
    ),
  )

  Ok(#(statement, transactions))
}
