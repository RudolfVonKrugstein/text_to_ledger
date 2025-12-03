import data/date
import data/money.{type Money}
import data/transaction_sheet
import extracted_data/extracted_data
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import input_loader/input_file

pub type LedgerEntry {
  LedgerEntry(
    input: input_file.InputFile,
    date: date.Date,
    payee: String,
    comment: String,
    lines: List(LedgerEntryLine),
  )
}

pub type LedgerEntryLine {
  LedgerEntryLine(account: String, amount: Money, comment: String)
}

fn line_to_string(line: LedgerEntryLine) {
  let comment = case line.comment {
    "" -> ""
    comment -> "; " <> string.replace(comment, "\n", "\n; ") <> "\n"
  }

  comment <> line.account <> "\t" <> money.to_string(line.amount)
}

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
  <> "\n  "
  <> string.join(entry_lines, "\n  ")
}

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
