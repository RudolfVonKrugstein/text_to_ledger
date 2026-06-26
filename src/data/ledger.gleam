//// A ledger entry for a ledger file.
//// This is the main output format.

import bigi
import data/date
import data/extracted_data
import data/money.{type Money}
import gleam/dynamic/decode
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import input_loader/input_file

/// An entry in a ledger
pub type LedgerEntry {
  LedgerEntry(
    /// The input file the ledger comes from
    input: option.Option(input_file.InputFile),
    /// The file to write this do (None for the default file)
    file: Option(String),
    /// The transaction date
    date: date.Date,
    /// The payee in the ledger description
    payee: String,
    /// Comment in front of the ledger
    comment: String,
    /// The lines, or blance changes, of the entry.
    lines: List(LedgerEntryLine),
  )
}

/// A Line in a ledger entry.
pub type LedgerEntryLine {
  LedgerEntryLine(
    /// The affected account
    account: String,
    /// The amount of money (or other unit) that is transfered
    amount: Money,
    /// Comment on the line
    comment: String,
  )
}

/// Create a new LedgerEntry with a transaction from one accoun to another
pub fn new(
  input input: option.Option(input_file.InputFile),
  file file: Option(String),
  date date: date.Date,
  payee payee: String,
  comment comment: String,
  accounts accounts: #(String, String),
  amount amount: Money,
) {
  let #(source_account, target_account) = accounts
  LedgerEntry(input:, file:, date:, payee:, comment:, lines: [
    LedgerEntryLine(account: source_account, amount:, comment: ""),
    LedgerEntryLine(
      account: target_account,
      amount: money.negate(amount),
      comment: "",
    ),
  ])
}

/// Get ledger from a json file.
pub fn decoder() -> decode.Decoder(LedgerEntry) {
  use date <- decode.optional_field("date", "1.1.1970", decode.string)
  use date <- decode.then(
    case date.parse_full_date(date, ".", date.DayMonthYear) {
      Ok(date) -> decode.success(date)
      Error(e) ->
        decode.failure(
          date.Date(1, 1, 1970),
          "unable to decode " <> date <> ": " <> e,
        )
    },
  )
  use payee <- decode.optional_field("payee", "Not set", decode.string)
  use comment <- decode.optional_field("comment", "", decode.string)
  use source_account <- decode.field("source_account", decode.string)
  use target_account <- decode.field("target_account", decode.string)
  use amount <- decode.field("amount", decode.string)
  use amount <- decode.then(case money.parse_money(amount, None, None) {
    Ok(amount) -> decode.success(amount)
    Error(e) ->
      decode.failure(
        money.Money(bigi.from_int(0), 0, "EUR"),
        "unable to decode " <> amount <> ": " <> e,
      )
  })

  decode.success(new(
    input: None,
    file: None,
    date:,
    payee:,
    comment:,
    accounts: #(source_account, target_account),
    amount:,
  ))
}

fn line_to_string(line: LedgerEntryLine) {
  let comment = case line.comment {
    "" -> ""
    comment -> "  ; " <> string.replace(comment, "\n", "\n  ; ") <> "\n"
  }

  comment <> "  " <> line.account <> "\t" <> money.to_string(line.amount)
}

/// Convert to the `LedgerEntry` to a string, that can be put into a ledger file
pub fn to_string(entry: LedgerEntry) {
  let comment = case entry.comment {
    "" -> ""
    comment -> "; " <> string.replace(comment, "\n", "\n; ") <> "\n"
  }

  let entry_lines = list.map(entry.lines, fn(line) { line_to_string(line) })

  comment
  <> date.to_string(entry.date)
  <> " "
  <> entry.payee
  <> "\n"
  <> string.join(entry_lines, "\n")
}

/// Create the ledger entry from extracted data
pub fn from_extracted_data(data: extracted_data.ExtractedData) {
  let file = extracted_data.get_optional_string(data, "file")

  use start_date <- result.try(extracted_data.get_optional_range_date(
    data,
    "start_date",
  ))
  let start_date = start_date |> option.map(date.first_possible_date)

  use end_date <- result.try(extracted_data.get_optional_range_date(
    data,
    "end_date",
  ))
  let end_date = end_date |> option.map(date.first_possible_date)

  use date <- result.try(extracted_data.get_trans_date(data, "date"))
  use date <- result.try(
    date.full_date_from_range(date, start_date, end_date)
    |> result.map_error(fn(e) {
      extracted_data.UnableToParse(
        key: "date",
        value: string.inspect(date),
        msg: e,
        value_type: "date",
      )
    }),
  )

  use amount <- result.try(extracted_data.get_money(data, "amount"))

  use payee <- result.try(extracted_data.get_string(data, "payee"))

  use source_account <- result.try(extracted_data.get_string(
    data,
    "source_account",
  ))

  use target_account <- result.try(extracted_data.get_string(
    data,
    "target_account",
  ))

  let comment =
    "loader: "
    <> data.input.loader
    <> "\nfile_name: "
    <> data.input.name
    <> "\nfile_title: "
    <> data.input.title
  let comment = case extracted_data.get_optional_string(data, "content") {
    None -> comment
    Some(content) -> comment <> "\ncontent:\n" <> content
  }

  Ok(
    LedgerEntry(input: Some(data.input), file:, date:, payee:, comment:, lines: [
      LedgerEntryLine(account: source_account, amount:, comment: ""),
      LedgerEntryLine(
        account: target_account,
        amount: money.negate(amount),
        comment: "",
      ),
    ]),
  )
}
