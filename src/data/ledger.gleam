import data/date
import data/money.{type Money}
import gleam/list
import gleam/string

pub type LedgerEntry {
  LedgerEntry(
    date: date.Date,
    subject: String,
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
  <> entry.subject
  <> "\n  "
  <> string.join(entry_lines, "\n  ")
}
