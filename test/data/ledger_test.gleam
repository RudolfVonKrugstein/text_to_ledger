import bigi
import data/date
import data/ledger
import data/money
import gleam/option.{Some}
import gleeunit/should
import input_loader/input_file

pub fn to_string_test() {
  let entry =
    ledger.LedgerEntry(
      input: input_file.InputFile(
        loader: "loader",
        name: "name",
        title: "title",
        content: "content",
        progress: 0,
        total_files: Some(1),
      ),
      date: date.Date(2025, 2, 1),
      payee: "payee",
      comment: "comment",
      lines: [
        ledger.LedgerEntryLine(
          account: "source_account",
          amount: money.Money(
            amount: bigi.from_int(123),
            decimal_pos: 2,
            currency: "EUR",
          ),
          comment: "comment1",
        ),
        ledger.LedgerEntryLine(
          account: "target_account",
          amount: money.Money(
            amount: bigi.from_int(-123),
            decimal_pos: 2,
            currency: "EUR",
          ),
          comment: "comment2",
        ),
      ],
    )

  let res = ledger.to_string(entry)

  should.equal(
    "; comment\n2025/02/01 payee\n  ; comment1\n  source_account\t1.23 EUR\n  ; comment2\n  target_account\t-1.23 EUR",
    res,
  )
}
