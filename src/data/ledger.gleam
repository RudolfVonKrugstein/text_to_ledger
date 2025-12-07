//// A ledger entry for a ledger file.
//// This is the main output format.

import data/date
import data/extracted_data
import data/money.{type Money}
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import input_loader/input_file

/// An entry in a ledger
pub type LedgerEntry {
  LedgerEntry(
    /// The input file the ledger comes from
    input: input_file.InputFile,
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

fn line_to_string(line: LedgerEntryLine) {
  let comment = case line.comment {
    "" -> ""
    comment -> "  ; " <> string.replace(comment, "\n", "\n  ; ")
  }

  comment <> "\n  " <> line.account <> "\t" <> money.to_string(line.amount)
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

  Ok(
    LedgerEntry(input: data.input, date:, payee:, comment: "", lines: [
      LedgerEntryLine(account: source_account, amount:, comment: ""),
      LedgerEntryLine(
        account: target_account,
        amount: money.negate(amount),
        comment: "",
      ),
    ]),
  )
}
