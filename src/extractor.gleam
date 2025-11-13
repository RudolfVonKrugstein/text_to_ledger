import data/bank_statement
import data/bank_transaction
import data/date
import data/money
import gleam/dict
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import input_loader/input_file
import regex/area_regex
import regex/regex
import regexp_ext
import template/template

/// The errors that can happen through extraction
pub type Error {
  RegexMatchError(input: input_file.InputFile, regex: String)
  TemplateRenderError(template: String, error: template.RenderError)
  ParseMoneyError(value: String, msg: String)
  ParseDateError(value: String, msg: String)
  CompleteTransDateError(msg: String)
}

pub fn error_string(e: Error) -> String {
  case e {
    RegexMatchError(input:, regex:) ->
      "Error matching regex:\n"
      <> regex
      <> "\non:\n"
      <> input_file.to_string(input)
    TemplateRenderError(template:, error:) ->
      "Error rendering template:\n"
      <> template
      <> "error: "
      <> template.error_string(error)
    ParseDateError(value:, msg:) ->
      "Unable to exract Money from " <> value <> ": " <> msg
    ParseMoneyError(value:, msg:) ->
      "Unable to exract Date from " <> value <> ": " <> msg
    CompleteTransDateError(msg:) ->
      "Unable to complete date of transaction: " <> msg
  }
}

/// Collect variables by applying regexes and getting all values for named captures groups.
fn collect_variables(
  regexes: List(regex.RegexWithOpts),
  input: input_file.InputFile,
) -> Result(dict.Dict(String, List(String)), Error) {
  extend_variables(regexes, input, template.empty_vars())
}

/// Extend variables by applying regexes and getting all values for named captures groups.
fn extend_variables(
  regexes: List(regex.RegexWithOpts),
  input: input_file.InputFile,
  start: template.Vars,
) -> Result(dict.Dict(String, List(String)), Error) {
  list.try_fold(regexes, start, fn(vars, regex) {
    let captures =
      regexp_ext.capture_names(with: regex.regex, over: input.content)

    case captures {
      [] if regex.optional == True -> Ok(vars)
      [] -> Error(RegexMatchError(input, regex.original))
      captures ->
        Ok(
          list.fold(list.flatten(captures), vars, fn(vars, capture) {
            let regexp_ext.NamedCapture(name:, value:) = capture

            template.add_to_vars(vars, name, value)
          }),
        )
    }
  })
}

// Helper function, like option.map but with a function that returns
// a result. The `Option` and `Result` container are than swapped.
pub fn option_map_result(
  opt: Option(a),
  trans: fn(a) -> Result(b, e),
) -> Result(Option(b), e) {
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
  option_map_result(temp, fn(temp) {
    template.render(temp, vars)
    |> result.map_error(fn(e) { TemplateRenderError(temp.input, e) })
  })
}

// Helper function, rendering a variable and parsing it as money.
fn extract_money(temp: template.Template, vars: template.Vars) {
  use amount <- result.try(
    template.render(temp, vars)
    |> result.map_error(TemplateRenderError(temp.input, _)),
  )

  money.parse_money(amount, Some("."), None)
  |> result.map_error(fn(e) { ParseMoneyError(amount, e) })
}

// Helper function, rendering a variable and  parsing a partial date
// that may be missing the year from it.
fn extract_trans_date(
  temp: template.Template,
  vars: template.Vars,
  min_date: Option(date.Date),
  max_date: Option(date.Date),
) -> Result(date.Date, Error) {
  use date <- result.try(
    template.render(temp, vars)
    |> result.map_error(TemplateRenderError(temp.input, _)),
  )

  use date <- result.try(
    date.parse_partial_date_with_day(date, ".", date.DayMonthYear)
    |> result.map_error(fn(e) { ParseDateError(date, e) }),
  )

  use date <- result.try(
    date.full_date_from_range(date, min_date, max_date)
    |> result.map_error(fn(e) { CompleteTransDateError(msg: e) }),
  )

  Ok(date)
}

// Helper function, rendering a variable and  parsing a partial date
// that may be missing the day and month from it.
// This dates occure in the date range of a bank statement.
fn extract_range_date(
  temp: template.Template,
  vars: template.Vars,
  start: Bool,
) -> Result(date.Date, Error) {
  use date <- result.try(
    template.render(temp, vars)
    |> result.map_error(TemplateRenderError(temp.input, _)),
  )

  use date <- result.try(
    date.parse_partial_date_with_year(date, ".", date.DayMonthYear)
    |> result.map_error(fn(e) { ParseDateError(date, e) }),
  )

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
  input: input_file.InputFile,
  trans_template: bank_transaction.BankTransactionTemplate,
  bank_vars: template.Vars,
  min_date: Option(date.Date),
  max_date: Option(date.Date),
) -> Result(bank_transaction.BankTransaction, Error) {
  // collect transaction variables
  use trans_vars <- result.try(extend_variables(
    trans_template.regexes,
    input,
    bank_vars,
  ))

  use subject <- result.try(
    template.render(trans_template.subject, trans_vars)
    |> result.map_error(TemplateRenderError(trans_template.subject.input, _)),
  )
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
    origin: input,
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
  input: input_file.InputFile,
  bs_template: bank_statement.BankStatementTemplate,
  trans_template: bank_transaction.BankTransactionTemplate,
) -> Result(
  #(bank_statement.BankStatement, List(bank_transaction.BankTransaction)),
  Error,
) {
  // collect bank variables
  use bank_vars <- result.try(collect_variables(bs_template.regexes, input))

  use bank <- result.try(option_render_template(bs_template.bank, bank_vars))
  use account <- result.try(
    template.render(bs_template.account, bank_vars)
    |> result.map_error(TemplateRenderError(bs_template.account.input, _)),
  )

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
      origin: input,
      bank:,
      account:,
      start_date:,
      end_date:,
      start_amount:,
      end_amount:,
    )

  let transaction_texts =
    area_regex.split(trans_template.area, input.content)
    |> list.map(fn(content) { input_file.InputFile(..input, content: content) })

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
